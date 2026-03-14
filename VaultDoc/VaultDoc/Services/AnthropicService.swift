import Foundation

struct AnthropicService {
    static func estimateValue(
        name: String,
        category: String,
        purchasePrice: Double,
        year: Int
    ) async throws -> Double {
        let apiKey = Config.Anthropic.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        let prompt = """
        You are a valuables appraiser. Given this item:
        - Name: \(name)
        - Category: \(category)
        - Purchase price: €\(purchasePrice)
        - Year purchased: \(year)

        Estimate the current market value in EUR.
        Reply with ONLY a number, no currency symbol, no explanation.
        """

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 64,
            "messages": [
                ["role": "user", "content": prompt]
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
              let text = content.first?["text"] as? String,
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AnthropicError.parseError
        }

        return value
    }
}

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case apiError
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Anthropic API key is missing from app configuration."
        case .apiError: return "API request failed."
        case .parseError: return "Could not parse AI response."
        }
    }
}
