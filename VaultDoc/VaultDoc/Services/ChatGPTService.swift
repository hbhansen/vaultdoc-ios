import Foundation

struct ChatGPTService {
    static var isConfigured: Bool {
        !Config.OpenAI.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func sendMessage(
        _ message: String,
        instructions: String? = nil,
        model: String? = nil
    ) async throws -> String {
        let apiKey = Config.OpenAI.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ChatGPTError.missingAPIKey
        }

        let resolvedModel = model ?? Config.OpenAI.model

        let body = ResponseRequest(
            model: resolvedModel,
            input: message,
            instructions: instructions
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatGPTError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ChatGPTError.apiError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponsePayload.self, from: data)

        if let text = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }

        throw ChatGPTError.parseError
    }
}

private struct ResponseRequest: Encodable {
    let model: String
    let input: String
    let instructions: String?
}

private struct ResponsePayload: Decodable {
    let output: [OutputItem]?
    let outputText: String?

    enum CodingKeys: String, CodingKey {
        case output
        case outputText = "output_text"
    }
}

private struct OutputItem: Decodable {
    let content: [OutputContent]?
}

private struct OutputContent: Decodable {
    let text: String?
}

enum ChatGPTError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing from app configuration."
        case .invalidResponse:
            return "The ChatGPT service returned an invalid response."
        case .apiError(let statusCode):
            return "OpenAI API request failed with status code \(statusCode)."
        case .parseError:
            return "Could not parse ChatGPT response."
        }
    }
}
