import Foundation
import Supabase

enum SignUpResult {
    case authenticated(PasswordRecoverySession)
    case confirmationRequired(email: String)
}

struct PasswordRecoverySession {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let userEmail: String
}

enum SupabaseAuthService {
    private static let passwordResetWebRedirectURL = URL(string: Config.PasswordReset.webRedirectURL)
    private static let appRedirectURL = URL(string: Config.PasswordReset.appRedirectURL)

    private static var client: SupabaseClient? {
        guard
            let url = URL(string: Config.Supabase.url),
            !Config.Supabase.anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.Supabase.anonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    static func isPasswordResetURL(_ url: URL) -> Bool {
        guard let appRedirectURL else {
            return false
        }

        guard url.scheme?.lowercased() == appRedirectURL.scheme?.lowercased() else {
            return false
        }

        let expectedHost = appRedirectURL.host?.lowercased()
        let expectedPath = appRedirectURL.path.lowercased()
        let host = url.host?.lowercased()
        let path = url.path.lowercased()
        let hostMatches = expectedHost == nil || host == expectedHost
        let pathMatches = expectedPath.isEmpty || path == expectedPath
        return hostMatches && pathMatches
    }

    static func signUp(email: String, password: String) async throws -> SignUpResult {
        guard let client else {
            throw PasswordResetError.invalidConfiguration
        }

        let response = try await client.auth.signUp(
            email: email,
            password: password
        )

        switch response {
        case .session(let session):
            return .authenticated(
                PasswordRecoverySession(
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken,
                    userId: session.user.id.uuidString,
                    userEmail: session.user.email ?? email
                )
            )
        case .user(let user):
            return .confirmationRequired(email: user.email ?? email)
        }
    }

    static func requestPasswordReset(email: String) async throws {
        guard let client else {
            throw PasswordResetError.invalidConfiguration
        }

        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: appRedirectURL ?? passwordResetWebRedirectURL
        )
    }

    static func completePasswordRecovery(from url: URL) async throws -> PasswordRecoverySession {
        guard let client else {
            throw PasswordResetError.invalidConfiguration
        }

        let callback = try PasswordRecoveryCallback(url: url)

        switch callback {
        case .session(let accessToken, let refreshToken, let type):
            guard type == "recovery" else {
                throw PasswordResetError.invalidRecoveryType
            }

            let session = try await client.auth.setSession(
                accessToken: accessToken,
                refreshToken: refreshToken
            )

            return PasswordRecoverySession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: session.user.id.uuidString,
                userEmail: session.user.email ?? ""
            )

        case .tokenHash(let tokenHash, let type):
            guard type == "recovery" else {
                throw PasswordResetError.invalidRecoveryType
            }

            let response = try await client.auth.verifyOTP(
                tokenHash: tokenHash,
                type: .recovery
            )

            let session = try await session(from: response, client: client)

            return PasswordRecoverySession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: session.user.id.uuidString,
                userEmail: session.user.email ?? ""
            )

        case .authCode(let code, let type):
            if let type, type != "recovery" {
                throw PasswordResetError.invalidRecoveryType
            }

            let session = try await client.auth.exchangeCodeForSession(authCode: code)

            return PasswordRecoverySession(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                userId: session.user.id.uuidString,
                userEmail: session.user.email ?? ""
            )
        }
    }

    static func updatePassword(to newPassword: String) async throws {
        guard let client else {
            throw PasswordResetError.invalidConfiguration
        }

        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }
}

private enum PasswordRecoveryCallback {
    case session(accessToken: String, refreshToken: String, type: String)
    case tokenHash(tokenHash: String, type: String)
    case authCode(code: String, type: String?)

    init(url: URL) throws {
        let parameters = Self.parameters(from: url)

        if
            let accessToken = parameters["access_token"],
            let refreshToken = parameters["refresh_token"],
            let type = parameters["type"],
            !accessToken.isEmpty,
            !refreshToken.isEmpty,
            !type.isEmpty
        {
            self = .session(
                accessToken: accessToken,
                refreshToken: refreshToken,
                type: type.lowercased()
            )
            return
        }

        if
            let tokenHash = parameters["token_hash"],
            let type = parameters["type"],
            !tokenHash.isEmpty,
            !type.isEmpty
        {
            self = .tokenHash(
                tokenHash: tokenHash,
                type: type.lowercased()
            )
            return
        }

        if let code = parameters["code"], !code.isEmpty {
            self = .authCode(
                code: code,
                type: parameters["type"]?.lowercased()
            )
            return
        }

        throw PasswordResetError.malformedRecoveryLink
    }

    private static func parameters(from url: URL) -> [String: String] {
        var parameters: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems where parameters[item.name] == nil {
                parameters[item.name] = item.value
            }
        }

        if let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let fragmentComponents = URLComponents(string: "?\(fragment)"),
           let queryItems = fragmentComponents.queryItems {
            for item in queryItems where parameters[item.name] == nil {
                parameters[item.name] = item.value
            }
        }

        return parameters
    }
}

private func session(
    from response: Supabase.AuthResponse,
    client: SupabaseClient
) async throws -> Session {
    switch response {
    case .session(let session):
        return session
    case .user:
        return try await client.auth.session
    }
}

enum PasswordResetError: LocalizedError {
    case invalidConfiguration
    case malformedRecoveryLink
    case invalidRecoveryType

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return L10n.tr("supabase.error.missing_configuration")
        case .malformedRecoveryLink:
            return L10n.tr("supabase.reset_link.invalid")
        case .invalidRecoveryType:
            return L10n.tr("supabase.reset_link.invalid_type")
        }
    }
}
