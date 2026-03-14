import Foundation
import Security

struct KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let service = "com.chatoyant.VaultDoc"

    func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension KeychainHelper {
    static let anthropicAPIKey = "anthropicAPIKey"

    // Supabase Auth
    static let supabaseAccessToken = "supabase_access_token"
    static let supabaseRefreshToken = "supabase_refresh_token"
    static let supabaseUserId = "supabase_user_id"
    static let supabaseUserEmail = "supabase_user_email"
}
