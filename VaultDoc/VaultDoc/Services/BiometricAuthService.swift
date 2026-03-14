import Foundation
import LocalAuthentication

struct BiometricAuthService {
    enum BiometricType: Equatable {
        case faceID
        case touchID
        case none

        var buttonTitle: String {
            switch self {
            case .faceID:
                return "Continue with Face ID"
            case .touchID:
                return "Continue with Touch ID"
            case .none:
                return "Continue"
            }
        }

        var promptReason: String {
            switch self {
            case .faceID:
                return "Use Face ID to unlock VaultDoc."
            case .touchID:
                return "Use Touch ID to unlock VaultDoc."
            case .none:
                return "Unlock VaultDoc."
            }
        }
    }

    static func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    static func authenticate() async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricAuthError.unavailable
        }

        let reason = biometricType().promptReason
        let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        guard success else {
            throw BiometricAuthError.failed
        }
    }
}

enum BiometricAuthError: LocalizedError {
    case unavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Face ID or Touch ID is not available on this device."
        case .failed:
            return "Biometric authentication failed."
        }
    }
}
