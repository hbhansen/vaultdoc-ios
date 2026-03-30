import Foundation

@MainActor
@Observable
class AuthService {
    static let shared = AuthService()

    enum AuthScreen {
        case signIn
        case forgotPassword
        case resetPasswordLanding
        case resetPassword
    }

    var isAuthenticated = false
    var hasStoredSession = false
    var canUseBiometricLogin = false
    var userId: String = ""
    var userEmail: String = ""
    var currentInventoryId: String = ""
    var currentUserProfile: UserProfilePayload?
    var inventoryMembers: [InventoryMemberPayload] = []
    var pendingInventoryInvites: [InventoryInvitePayload] = []
    var sharedInventoryInvites: [InventoryInvitePayload] = []
    var isLoading = false
    var errorMessage: String?
    var infoMessage: String?
    var debugMessage: String?
    var biometricButtonTitle = BiometricAuthService.BiometricType.none.buttonTitle
    var authScreen: AuthScreen = .signIn
    var isPasswordRecoveryActive = false
    var didCompletePasswordReset = false
    var pendingPasswordRecoveryURL: URL?

    let minimumPasswordLength = 8

    var effectiveInventoryId: String {
        currentInventoryId.isEmpty ? userId : currentInventoryId
    }

    var showsAuthenticatedContent: Bool {
        isAuthenticated && !isPasswordRecoveryActive
    }

    private init() {
        // Load cached user info synchronously so userId is available before restoreSession completes
        if let id = KeychainHelper.shared.load(forKey: KeychainHelper.supabaseUserId),
           let email = KeychainHelper.shared.load(forKey: KeychainHelper.supabaseUserEmail),
           KeychainHelper.shared.load(forKey: KeychainHelper.supabaseRefreshToken) != nil {
            userId = id
            userEmail = email
            hasStoredSession = true
            // Don't set isAuthenticated yet — wait for token refresh in restoreSession()
        }
        refreshBiometricAvailability()
    }

    // MARK: - Session Restore (called on app launch)

    func restoreSession() async {
        guard let refreshToken = KeychainHelper.shared.load(forKey: KeychainHelper.supabaseRefreshToken) else {
            hasStoredSession = false
            refreshBiometricAvailability()
            return
        }
        do {
            try await refreshSession(with: refreshToken)
            await refreshUserContext()
        } catch {
            clearSession()
        }
    }

    func refreshBiometricAvailability() {
        let biometricType = BiometricAuthService.biometricType()
        biometricButtonTitle = biometricType.buttonTitle
        canUseBiometricLogin = hasStoredSession && biometricType != .none
    }

    func signInWithBiometrics() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            try await BiometricAuthService.authenticate()
            await restoreSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            errorMessage = L10n.tr("auth.error.empty_credentials")
            return
        }

        do {
            let url = URL(string: "\(Config.Supabase.url)/auth/v1/signup")!
            let body = ["email": normalizedEmail, "password": normalizedPassword]
            let response: AuthResponse = try await postJSON(url: url, body: body)
            handleAuthResponse(response)
            authScreen = .signIn
            await refreshUserContext()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            errorMessage = L10n.tr("auth.error.empty_credentials")
            return
        }

        do {
            let url = URL(string: "\(Config.Supabase.url)/auth/v1/token?grant_type=password")!
            let body = ["email": normalizedEmail, "password": normalizedPassword]
            let response: AuthResponse = try await postJSON(url: url, body: body)
            handleAuthResponse(response)
            authScreen = .signIn
            await refreshUserContext()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Password Reset

    func showSignIn() {
        authScreen = .signIn
        errorMessage = nil
        infoMessage = nil
        debugMessage = nil
        pendingPasswordRecoveryURL = nil
    }

    func showForgotPassword() {
        authScreen = .forgotPassword
        errorMessage = nil
        infoMessage = nil
        debugMessage = nil
    }

    func recordIncomingURL(_ url: URL) {
        debugMessage = "Received link: \(url.absoluteString)"
    }

    func requestPasswordReset(email: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            errorMessage = "Enter your email to reset your password."
            infoMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        debugMessage = nil
        defer { isLoading = false }

        do {
            try await SupabaseAuthService.requestPasswordReset(email: normalizedEmail)
        } catch {
            // Always show a generic success state so the flow never reveals account existence.
        }

        infoMessage = "If an account exists for that email, a password reset link has been sent."
    }

    func handleIncomingURL(_ url: URL) async {
        guard SupabaseAuthService.isPasswordResetURL(url) else {
            debugMessage = "Ignored non-reset link: \(url.absoluteString)"
            return
        }

        errorMessage = nil
        infoMessage = nil
        isPasswordRecoveryActive = true
        didCompletePasswordReset = false
        pendingPasswordRecoveryURL = url
        authScreen = .resetPasswordLanding
        debugMessage = "Recovery link received. Continue to reset your password."
    }

    func beginPasswordRecovery() async {
        guard let recoveryURL = pendingPasswordRecoveryURL else {
            errorMessage = "This password reset link is missing required information."
            authScreen = .signIn
            isPasswordRecoveryActive = false
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        debugMessage = "Handling reset link…"
        defer { isLoading = false }

        do {
            let session = try await SupabaseAuthService.completePasswordRecovery(from: recoveryURL)
            applyRecoveredSession(session)
            isPasswordRecoveryActive = true
            didCompletePasswordReset = false
            pendingPasswordRecoveryURL = nil
            authScreen = .resetPassword
            debugMessage = "Recovery session established for \(session.userEmail.isEmpty ? session.userId : session.userEmail)."
            await refreshUserContext()
        } catch {
            errorMessage = error.localizedDescription
            authScreen = .resetPasswordLanding
            debugMessage = "Reset link handling failed: \(error.localizedDescription)"
        }
    }

    func updateRecoveredPassword(newPassword: String, confirmPassword: String) async {
        let normalizedPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedConfirmation = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedPassword.isEmpty, !normalizedConfirmation.isEmpty else {
            errorMessage = "Enter and confirm your new password."
            return
        }

        guard normalizedPassword.count >= minimumPasswordLength else {
            errorMessage = "Use at least \(minimumPasswordLength) characters for your new password."
            return
        }

        guard normalizedPassword == normalizedConfirmation else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }

        do {
            try await SupabaseAuthService.updatePassword(to: normalizedPassword)
            didCompletePasswordReset = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishPasswordResetFlow() {
        errorMessage = nil
        infoMessage = nil
        didCompletePasswordReset = false
        isPasswordRecoveryActive = false
        pendingPasswordRecoveryURL = nil
        authScreen = .signIn
        debugMessage = nil
    }

    // MARK: - Sign Out

    func signOut() async {
        if let token = KeychainHelper.shared.load(forKey: KeychainHelper.supabaseAccessToken) {
            var request = URLRequest(url: URL(string: "\(Config.Supabase.url)/auth/v1/logout")!)
            request.httpMethod = "POST"
            request.setValue(Config.Supabase.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        clearSession()
    }

    // MARK: - Token Refresh

    private func refreshSession(with refreshToken: String) async throws {
        let url = URL(string: "\(Config.Supabase.url)/auth/v1/token?grant_type=refresh_token")!
        let body = ["refresh_token": refreshToken]
        let response: AuthResponse = try await postJSON(url: url, body: body)
        handleAuthResponse(response)
    }

    func refreshUserContext() async {
        guard isAuthenticated, !userId.isEmpty else { return }

        do {
            let context = try await CollaborationService.loadContext(userId: userId, email: userEmail)
            currentUserProfile = context.profile
            currentInventoryId = context.inventoryId
            inventoryMembers = context.inventoryMembers
            pendingInventoryInvites = context.pendingInvites
            sharedInventoryInvites = context.sharedInvites
        } catch {
            errorMessage = error.localizedDescription
            currentUserProfile = nil
            currentInventoryId = userId
            inventoryMembers = []
            pendingInventoryInvites = []
            sharedInventoryInvites = []
        }
    }

    // MARK: - Helpers

    private func handleAuthResponse(_ response: AuthResponse) {
        KeychainHelper.shared.save(response.accessToken, forKey: KeychainHelper.supabaseAccessToken)
        KeychainHelper.shared.save(response.refreshToken, forKey: KeychainHelper.supabaseRefreshToken)
        KeychainHelper.shared.save(response.user.id, forKey: KeychainHelper.supabaseUserId)
        KeychainHelper.shared.save(response.user.email, forKey: KeychainHelper.supabaseUserEmail)

        hasStoredSession = true
        userId = response.user.id
        userEmail = response.user.email
        currentInventoryId = ""
        currentUserProfile = nil
        inventoryMembers = []
        pendingInventoryInvites = []
        sharedInventoryInvites = []
        isAuthenticated = true
        refreshBiometricAvailability()
    }

    private func clearSession() {
        KeychainHelper.shared.delete(forKey: KeychainHelper.supabaseAccessToken)
        KeychainHelper.shared.delete(forKey: KeychainHelper.supabaseRefreshToken)
        KeychainHelper.shared.delete(forKey: KeychainHelper.supabaseUserId)
        KeychainHelper.shared.delete(forKey: KeychainHelper.supabaseUserEmail)

        isAuthenticated = false
        hasStoredSession = false
        canUseBiometricLogin = false
        userId = ""
        userEmail = ""
        currentInventoryId = ""
        currentUserProfile = nil
        inventoryMembers = []
        pendingInventoryInvites = []
        sharedInventoryInvites = []
        infoMessage = nil
        debugMessage = nil
        authScreen = .signIn
        isPasswordRecoveryActive = false
        didCompletePasswordReset = false
        pendingPasswordRecoveryURL = nil
        biometricButtonTitle = BiometricAuthService.BiometricType.none.buttonTitle
    }

    private func applyRecoveredSession(_ session: PasswordRecoverySession) {
        KeychainHelper.shared.save(session.accessToken, forKey: KeychainHelper.supabaseAccessToken)
        KeychainHelper.shared.save(session.refreshToken, forKey: KeychainHelper.supabaseRefreshToken)
        KeychainHelper.shared.save(session.userId, forKey: KeychainHelper.supabaseUserId)
        KeychainHelper.shared.save(session.userEmail, forKey: KeychainHelper.supabaseUserEmail)

        hasStoredSession = true
        isAuthenticated = true
        userId = session.userId
        userEmail = session.userEmail
        currentInventoryId = ""
        currentUserProfile = nil
        inventoryMembers = []
        pendingInventoryInvites = []
        sharedInventoryInvites = []
        refreshBiometricAvailability()
    }

    private func postJSON<T: Decodable>(url: URL, body: [String: String]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.Supabase.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw AuthError.serverError(
                    errorResponse.errorDescription
                    ?? errorResponse.message
                    ?? errorResponse.msg
                    ?? L10n.format("auth.error.unknown_http", Int64(http.statusCode))
                )
            }
            throw AuthError.serverError(L10n.format("auth.error.http_status", Int64(http.statusCode)))
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Response Models

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct AuthUser: Decodable {
    let id: String
    let email: String
}

struct AuthErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?
}

enum AuthError: LocalizedError {
    case networkError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .networkError: return L10n.tr("auth.error.network_request_failed")
        case .serverError(let msg): return msg
        }
    }
}
