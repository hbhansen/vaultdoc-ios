import Foundation

// MARK: - Supabase Data Service

struct SupabaseDataService {

    private static let baseURL = Config.Supabase.url
    private static let apiKey = Config.Supabase.anonKey
    private static let bucketName = "vault-files"

    // MARK: - Items

    static func insertItem(_ payload: ItemPayload) async throws -> ItemPayload {
        let url = URL(string: "\(baseURL)/rest/v1/items")!
        return try await postJSON(url: url, body: payload)
    }

    static func updateItem(id: UUID, _ payload: ItemPayload) async throws -> ItemPayload {
        let url = URL(string: "\(baseURL)/rest/v1/items?id=eq.\(id.uuidString)")!
        return try await patchJSON(url: url, body: payload)
    }

    static func deleteItem(id: UUID) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/items?id=eq.\(id.uuidString)")!
        try await delete(url: url)
    }

    static func fetchItems(inventoryId: String) async throws -> [ItemPayload] {
        let encodedInventoryId = inventoryId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? inventoryId
        let url = URL(string: "\(baseURL)/rest/v1/items?inventory_id=eq.\(encodedInventoryId)&order=created_at.desc")!
        return try await get(url: url)
    }

    static func fetchItems(userId: String) async throws -> [ItemPayload] {
        let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userId
        let url = URL(string: "\(baseURL)/rest/v1/items?user_id=eq.\(encodedUserId)&order=created_at.desc")!
        return try await get(url: url)
    }

    // MARK: - Photo Records

    static func insertPhotoRecord(_ payload: PhotoPayload) async throws -> PhotoPayload {
        let url = URL(string: "\(baseURL)/rest/v1/item_photos")!
        return try await postJSON(url: url, body: payload)
    }

    static func fetchPhotos(itemIds: [UUID]) async throws -> [PhotoPayload] {
        guard !itemIds.isEmpty else { return [] }
        let idList = itemIds.map { "\"\($0.uuidString)\"" }.joined(separator: ",")
        let url = URL(string: "\(baseURL)/rest/v1/item_photos?item_id=in.(\(idList))")!
        return try await get(url: url)
    }

    static func deletePhotoRecord(id: UUID) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/item_photos?id=eq.\(id.uuidString)")!
        try await delete(url: url)
    }

    // MARK: - Document Records

    static func insertDocumentRecord(_ payload: DocPayload) async throws -> DocPayload {
        let url = URL(string: "\(baseURL)/rest/v1/item_documents")!
        return try await postJSON(url: url, body: payload)
    }

    static func fetchDocuments(itemIds: [UUID]) async throws -> [DocPayload] {
        guard !itemIds.isEmpty else { return [] }
        let idList = itemIds.map { "\"\($0.uuidString)\"" }.joined(separator: ",")
        let url = URL(string: "\(baseURL)/rest/v1/item_documents?item_id=in.(\(idList))")!
        return try await get(url: url)
    }

    static func deleteDocumentRecord(id: UUID) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/item_documents?id=eq.\(id.uuidString)")!
        try await delete(url: url)
    }

    // MARK: - Storage (binary file upload/download)

    static func uploadFile(inventoryId: String, itemId: UUID, fileId: UUID, filename: String, data: Data, contentType: String) async throws -> String {
        let path = "\(inventoryId)/\(itemId.uuidString.lowercased())/\(fileId.uuidString.lowercased())_\(filename)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/storage/v1/object/\(bucketName)/\(encodedPath)") else {
            print("[SupabaseDataService] Upload failed: could not build URL for path: \(path)")
            throw DataServiceError.uploadFailed
        }

        print("[SupabaseDataService] Uploading to: \(url.absoluteString)")
        print("[SupabaseDataService] File size: \(data.count) bytes, contentType: \(contentType)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try bearerToken())", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        // Allow overwriting if file exists
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DataServiceError.uploadFailed
        }
        let responseBody = String(data: responseData, encoding: .utf8) ?? "(no body)"
        print("[SupabaseDataService] Upload response status: \(http.statusCode)")
        print("[SupabaseDataService] Upload response body: \(responseBody)")

        guard (200...299).contains(http.statusCode) else {
            throw mapUploadError(statusCode: http.statusCode, responseBody: responseBody)
        }
        return path
    }

    static func downloadFile(path: String) async throws -> Data {
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/storage/v1/object/\(bucketName)/\(encodedPath)") else {
            throw DataServiceError.downloadFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try bearerToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DataServiceError.downloadFailed
        }
        return data
    }

    static func deleteFiles(paths: [String]) async throws {
        guard !paths.isEmpty else { return }
        let url = URL(string: "\(baseURL)/storage/v1/object/\(bucketName)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try bearerToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["prefixes": paths]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: responseData, encoding: .utf8) ?? "Delete failed"
            throw DataServiceError.serverError(msg)
        }
    }

    // MARK: - Full Sync

    static func fetchAllUserData(inventoryId: String) async throws -> ([ItemPayload], [PhotoPayload], [DocPayload]) {
        let items = try await fetchItems(inventoryId: inventoryId)
        let itemIds = items.map(\.id)

        async let photosResult: [PhotoPayload] = {
            do {
                return try await fetchPhotos(itemIds: itemIds)
            } catch {
                print("[SupabaseDataService] Shared sync warning: failed to fetch photo records: \(error)")
                return []
            }
        }()

        async let docsResult: [DocPayload] = {
            do {
                return try await fetchDocuments(itemIds: itemIds)
            } catch {
                print("[SupabaseDataService] Shared sync warning: failed to fetch document records: \(error)")
                return []
            }
        }()

        return await (items, photosResult, docsResult)
    }

    // MARK: - User Profile

    static func fetchUserProfile(userId: String) async throws -> UserProfilePayload? {
        let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userId
        let url = URL(string: "\(baseURL)/rest/v1/profiles?id=eq.\(encodedUserId)&select=id,email,default_currency,inventory_id")!
        let profiles: [UserProfilePayload] = try await get(url: url)
        return profiles.first
    }

    static func fetchUserProfile(email: String) async throws -> UserProfilePayload? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let encodedEmail = normalizedEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalizedEmail
        let url = URL(string: "\(baseURL)/rest/v1/profiles?email=eq.\(encodedEmail)&select=id,email,default_currency,inventory_id")!
        let profiles: [UserProfilePayload] = try await get(url: url)
        return profiles.first
    }

    static func upsertUserProfile(_ payload: UserProfilePayload) async throws -> UserProfilePayload {
        let url = URL(string: "\(baseURL)/rest/v1/profiles")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in try authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw DataServiceError.serverError(msg)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let profiles = try decoder.decode([UserProfilePayload].self, from: data)
        guard let first = profiles.first else { throw DataServiceError.emptyResponse }
        return first
    }

    static func fetchInventoryMembers(inventoryId: String) async throws -> [InventoryMemberPayload] {
        let encodedInventoryId = inventoryId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? inventoryId
        let url = URL(string: "\(baseURL)/rest/v1/profiles?inventory_id=eq.\(encodedInventoryId)&select=id,email&order=email.asc")!
        return try await get(url: url)
    }

    static func fetchPendingInventoryInvites(email: String) async throws -> [InventoryInvitePayload] {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let encodedEmail = normalizedEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalizedEmail
        let url = URL(
            string: "\(baseURL)/rest/v1/inventory_invites?invited_email=eq.\(encodedEmail)&status=eq.pending&order=created_at.desc"
        )!
        return try await get(url: url)
    }

    static func createInventoryInvite(_ payload: InventoryInvitePayload) async throws -> InventoryInvitePayload {
        let url = URL(string: "\(baseURL)/rest/v1/inventory_invites")!
        return try await postJSON(url: url, body: payload)
    }

    static func updateInventoryInvite(_ payload: InventoryInvitePayload) async throws -> InventoryInvitePayload {
        let url = URL(string: "\(baseURL)/rest/v1/inventory_invites?id=eq.\(payload.id.uuidString)")!
        return try await patchJSON(url: url, body: payload)
    }

    // MARK: - Private Helpers

    private static func bearerToken() throws -> String {
        guard let token = KeychainHelper.shared.load(forKey: KeychainHelper.supabaseAccessToken) else {
            throw DataServiceError.notAuthenticated
        }
        return token
    }

    private static func authHeaders() throws -> [(String, String)] {
        [
            ("apikey", apiKey),
            ("Authorization", "Bearer \(try bearerToken())"),
            ("Content-Type", "application/json"),
            ("Prefer", "return=representation")
        ]
    }

    private static func postJSON<T: Codable>(url: URL, body: T) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in try authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(supabaseDateFormatter.string(from: date))
        }
        request.httpBody = try encoder.encode(body)

        print("[SupabaseDataService] POST \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DataServiceError.serverError("No HTTP response")
        }
        let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
        print("[SupabaseDataService] POST response status: \(http.statusCode)")
        if http.statusCode >= 300 {
            print("[SupabaseDataService] POST response body: \(responseBody)")
        }
        guard (200...299).contains(http.statusCode) else {
            throw DataServiceError.serverError(responseBody)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = supabaseDateFormatter.date(from: str) { return date }
            // Fallback: try without fractional seconds
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }

        // PostgREST returns an array even for single insert with Prefer: return=representation
        let items = try decoder.decode([T].self, from: data)
        guard let first = items.first else { throw DataServiceError.emptyResponse }
        return first
    }

    private static func patchJSON<T: Codable>(url: URL, body: T) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        for (key, value) in try authHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(supabaseDateFormatter.string(from: date))
        }
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw DataServiceError.serverError(msg)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = supabaseDateFormatter.date(from: str) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }

        let items = try decoder.decode([T].self, from: data)
        guard let first = items.first else { throw DataServiceError.emptyResponse }
        return first
    }

    private static func get<T: Decodable>(url: URL) async throws -> [T] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try bearerToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw DataServiceError.serverError(msg)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = supabaseDateFormatter.date(from: str) { return date }
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return try decoder.decode([T].self, from: data)
    }

    private static func delete(url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try bearerToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw DataServiceError.serverError(msg)
        }
    }

    private static func mapUploadError(statusCode: Int, responseBody: String) -> DataServiceError {
        let normalizedBody = responseBody.lowercased()
        if statusCode == 404 || normalizedBody.contains("bucket") && normalizedBody.contains("not found") {
            return .serverError(
                "Storage bucket '\(bucketName)' was not found in Supabase project '\(supabaseProjectRef())'. " +
                "Create it in Supabase Dashboard → Storage as a private bucket, or update the app config if this app should use a different project."
            )
        }

        return .serverError("Upload failed (HTTP \(statusCode)): \(responseBody)")
    }

    private static func supabaseProjectRef() -> String {
        URL(string: baseURL)?
            .host?
            .split(separator: ".")
            .first
            .map(String.init) ?? baseURL
    }
}

// MARK: - Payload Models

struct ItemPayload: Codable {
    var id: UUID
    var userId: String
    var inventoryId: String
    var name: String
    var category: String
    var currency: String
    var purchasePrice: Double
    var estimatedValue: Double
    var aiEstimate: Double?
    var yearPurchased: Int
    var serialNumber: String
    var notes: String
    var createdAt: Date
}

struct PhotoPayload: Codable {
    var id: UUID
    var itemId: UUID
    var storagePath: String
    var capturedAt: Date
}

struct DocPayload: Codable {
    var id: UUID
    var itemId: UUID
    var filename: String
    var storagePath: String
    var fileSize: Int
    var addedAt: Date
}

struct UserProfilePayload: Codable {
    var id: String
    var email: String?
    var defaultCurrency: String?
    var inventoryId: String?
}

struct InventoryMemberPayload: Codable, Identifiable {
    var id: String
    var email: String?
}

struct InventoryInvitePayload: Codable, Identifiable {
    var id: UUID
    var inventoryId: String
    var invitedEmail: String
    var invitedByUserId: String
    var invitedByEmail: String
    var status: String
    var createdAt: Date
}

// MARK: - Date Formatter

private let supabaseDateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

// MARK: - Errors

enum DataServiceError: LocalizedError {
    case notAuthenticated
    case uploadFailed
    case downloadFailed
    case deleteFailed
    case serverError(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated. Please sign in."
        case .uploadFailed: return "Failed to upload file."
        case .downloadFailed: return "Failed to download file."
        case .deleteFailed: return "Failed to delete file."
        case .serverError(let msg): return "Server error: \(msg)"
        case .emptyResponse: return "Server returned an empty response."
        }
    }
}
