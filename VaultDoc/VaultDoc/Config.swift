import Foundation

// MARK: - App Configuration
// Keep live secrets out of source control. Provide them via scheme environment
// variables or a local Secrets.plist added to the app target.

enum Config {
    enum Supabase {
        static let url = "https://twblphtenjgfhtdbexgx.supabase.co"
        static let anonKey = SecretStore.value(for: "SUPABASE_ANON_KEY")
    }

    enum PasswordReset {
        static let webRedirectURL = "https://vaultdoc.chatoyant.ventures"
        static let appRedirectURL = "vaultdoc://reset-password"
    }

    enum Anthropic {
        static let apiKey = SecretStore.value(for: "ANTHROPIC_API_KEY")
    }

    enum OpenAI {
        static let apiKey = SecretStore.value(for: "OPENAI_API_KEY")
        static let model = "gpt-5"
    }
}

private enum SecretStore {
    static func value(for key: String) -> String {
        if let environmentValue = ProcessInfo.processInfo.environment[key]?.trimmed,
           !environmentValue.isEmpty {
            return environmentValue
        }

        if let bundledValue = bundledSecrets[key]?.trimmed,
           !bundledValue.isEmpty {
            return bundledValue
        }

        return ""
    }

    private static let bundledSecrets: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let secrets = plist as? [String: String] else {
            return [:]
        }

        return secrets
    }()
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
