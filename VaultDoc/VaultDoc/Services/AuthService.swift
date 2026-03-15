import Foundation

@Observable
class AuthService {
    static let shared = AuthService()

    var isAuthenticated = false
    var hasStoredSession = false
    var canUseBiometricLogin = false
    var userId: String = ""
    var userEmail: String = ""
    var currentInventoryId: String = ""
    var currentUserProfile: UserProfilePayload?
    var inventoryMembers: [InventoryMemberPayload] = []
    var pendingInventoryInvites: [InventoryInvitePayload] = []
    var isLoading = false
    var errorMessage: String?
    var biometricButtonTitle = BiometricAuthService.BiometricType.none.buttonTitle

    var effectiveInventoryId: String {
        currentInventoryId.isEmpty ? userId : currentInventoryId
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
        defer { isLoading = false }

        do {
            let url = URL(string: "\(Config.Supabase.url)/auth/v1/signup")!
            let body = ["email": email, "password": password]
            let response: AuthResponse = try await postJSON(url: url, body: body)
            handleAuthResponse(response)
            await refreshUserContext()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let url = URL(string: "\(Config.Supabase.url)/auth/v1/token?grant_type=password")!
            let body = ["email": email, "password": password]
            let response: AuthResponse = try await postJSON(url: url, body: body)
            handleAuthResponse(response)
            await refreshUserContext()
        } catch {
            errorMessage = error.localizedDescription
        }
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
            let normalizedEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let profile: UserProfilePayload
            if let existingProfile = try await SupabaseDataService.fetchUserProfile(userId: userId) {
                profile = existingProfile
            } else {
                let payload = UserProfilePayload(
                    id: userId,
                    email: normalizedEmail,
                    defaultCurrency: nil,
                    inventoryId: userId
                )
                profile = try await SupabaseDataService.upsertUserProfile(payload)
            }
            currentUserProfile = profile
            currentInventoryId = profile.inventoryId ?? userId

            async let members = SupabaseDataService.fetchInventoryMembers(inventoryId: currentInventoryId)
            async let invites = SupabaseDataService.fetchPendingInventoryInvites(email: normalizedEmail)

            inventoryMembers = try await members
            pendingInventoryInvites = try await invites
        } catch {
            errorMessage = error.localizedDescription
            currentUserProfile = nil
            currentInventoryId = userId
            inventoryMembers = []
            pendingInventoryInvites = []
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
        biometricButtonTitle = BiometricAuthService.BiometricType.none.buttonTitle
    }

    private func postJSON<T: Decodable>(url: URL, body: [String: String]) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.Supabase.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }

        guard http.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
                throw AuthError.serverError(
                    errorResponse.errorDescription
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
