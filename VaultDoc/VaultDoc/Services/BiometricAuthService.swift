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
                return L10n.tr("biometric.button.face_id")
            case .touchID:
                return L10n.tr("biometric.button.touch_id")
            case .none:
                return L10n.tr("Continue")
            }
        }

        var promptReason: String {
            switch self {
            case .faceID:
                return L10n.tr("biometric.prompt.face_id")
            case .touchID:
                return L10n.tr("biometric.prompt.touch_id")
            case .none:
                return L10n.tr("biometric.prompt.default")
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
        context.localizedCancelTitle = L10n.tr("Cancel")

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
            return L10n.tr("biometric.error.unavailable")
        case .failed:
            return L10n.tr("biometric.error.failed")
        }
    }
}
