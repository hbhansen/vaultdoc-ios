import Foundation

struct AnthropicService {
    struct ObjectValuation: Sendable {
        let identifiedObject: String
        let make: String?
        let model: String?
        let amount: Double
    }

    static var isConfigured: Bool {
        !Config.Anthropic.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func estimateValue(
        name: String,
        category: String,
        purchasePrice: Double,
        year: Int
    ) async throws -> Double {
        let prompt = """
        You are a valuables appraiser. Given this item:
        - Name: \(name)
        - Category: \(category)
        - Purchase price: €\(purchasePrice)
        - Year purchased: \(year)

        Estimate the current market value in EUR.
        Reply with ONLY a number, no currency symbol, no explanation.
        """

        let text = try await sendMessage(
            [
                ["type": "text", "text": prompt]
            ],
            maxTokens: 64
        )

        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AnthropicError.parseError
        }

        return value
    }

    static func valuateObject(
        nameHint: String,
        categoryHint: String,
        purchasePrice: Double,
        purchaseDate: Date,
        currency: String,
        countryCode: String,
        photos: [Data]
    ) async throws -> ObjectValuation {
        guard !photos.isEmpty else {
            throw AnthropicError.missingPhotos
        }

        let purchaseYear = Calendar.current.component(.year, from: purchaseDate)
        let countryName = Locale.autoupdatingCurrent.localizedString(forRegionCode: countryCode) ?? countryCode

        let prompt = """
        You are a valuation specialist for insured household objects.
        Analyze the uploaded photos and return JSON only.

        Requirements:
        - Identify the primary subject from the photos.
        - The subject must be a non-living object. If it is a person, animal, plant, food, or any other living thing, mark it unsupported.
        - Infer the most likely make or brand and model when visible or reasonably identifiable.
        - Estimate the current market value using the purchase date, purchase price, country, and visible condition.
        - Use the provided currency code for the amount.
        - Do not include markdown fences or commentary.

        Context:
        - Name hint: \(nameHint.isEmpty ? "None" : nameHint)
        - Category hint: \(categoryHint)
        - Purchase price: \(purchasePrice)
        - Purchase year: \(purchaseYear)
        - Country: \(countryName) (\(countryCode))
        - Currency: \(currency)

        Return this JSON object:
        {
          "supported": true,
          "identified_object": "string",
          "make": "string or null",
          "model": "string or null",
          "amount": 1234.56
        }
        """

        let imageContent: [[String: Any]] = photos.compactMap { data in
            guard let mediaType = mediaType(for: data) else { return nil }
            return [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": mediaType,
                    "data": data.base64EncodedString()
                ]
            ]
        }

        guard !imageContent.isEmpty else {
            throw AnthropicError.unsupportedImageFormat
        }

        let text = try await sendMessage(
            [
                ["type": "text", "text": prompt]
            ] + imageContent,
            maxTokens: 256
        )

        let cleanedText = normalizedJSONText(from: text)
        guard let responseData = cleanedText.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let supported = parsed["supported"] as? Bool else {
            throw AnthropicError.parseError
        }

        guard supported else {
            throw AnthropicError.unsupportedSubject
        }

        guard let identifiedObject = parsed["identified_object"] as? String,
              let amount = parsed["amount"] as? Double else {
            throw AnthropicError.parseError
        }

        return ObjectValuation(
            identifiedObject: identifiedObject,
            make: parsed["make"] as? String,
            model: parsed["model"] as? String,
            amount: amount
        )
    }

    private static func sendMessage(
        _ content: [[String: Any]],
        maxTokens: Int
    ) async throws -> String {
        let apiKey = Config.Anthropic.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AnthropicError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AnthropicError.parseError
        }

        return text
    }

    private static func normalizedJSONText(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```"),
           let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            return String(trimmed[firstBrace...lastBrace])
        }
        return trimmed
    }

    private static func mediaType(for data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "image/gif"
        }
        if bytes.count >= 12,
           bytes[0...3].elementsEqual([0x52, 0x49, 0x46, 0x46]),
           bytes[8...11].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
            return "image/webp"
        }
        return nil
    }
}

enum AnthropicError: LocalizedError, Equatable {
    case missingAPIKey
    case missingPhotos
    case apiError
    case parseError
    case unsupportedImageFormat
    case unsupportedSubject

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return L10n.tr("anthropic.error.missing_api_key")
        case .missingPhotos: return L10n.tr("valuation.error.missing_photos")
        case .apiError: return L10n.tr("valuation.error.api_request_failed")
        case .parseError: return L10n.tr("valuation.error.parse_failed")
        case .unsupportedImageFormat: return L10n.tr("valuation.error.unsupported_image_format")
        case .unsupportedSubject: return L10n.tr("valuation.error.unsupported_subject")
        }
    }
}
