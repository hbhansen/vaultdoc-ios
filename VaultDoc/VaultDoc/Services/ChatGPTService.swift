import Foundation

struct ChatGPTService {
    struct ObjectValuation: Sendable {
        let identifiedObject: String
        let make: String?
        let model: String?
        let amount: Double
    }

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

    static func valuateObject(
        nameHint: String,
        categoryHint: String,
        purchasePrice: Double,
        purchaseDate: Date,
        currency: String,
        countryCode: String,
        photos: [Data]
    ) async throws -> ObjectValuation {
        let apiKey = Config.OpenAI.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ChatGPTError.missingAPIKey
        }

        guard !photos.isEmpty else {
            throw ChatGPTError.missingPhotos
        }

        let body = VisionResponseRequest(
            model: Config.OpenAI.model,
            input: [
                VisionInputMessage(
                    role: "user",
                    content: [
                        .text(
                            ValuationRules.objectValuationPrompt(
                                nameHint: nameHint,
                                categoryHint: categoryHint,
                                purchasePrice: purchasePrice,
                                purchaseDate: purchaseDate,
                                currency: currency,
                                countryCode: countryCode
                            )
                        )
                    ] + photos.compactMap { data in
                        guard let dataURL = dataURL(for: data) else { return nil }
                        return .image(dataURL)
                    }
                )
            ]
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
        guard let text = decoded.outputText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ChatGPTError.parseError
        }

        let cleanedText = normalizedJSONText(from: text)
        guard let responseData = cleanedText.data(using: .utf8) else {
            throw ChatGPTError.parseError
        }

        let valuationResponse = try JSONDecoder().decode(ValuationResponse.self, from: responseData)

        guard valuationResponse.supported else {
            throw ChatGPTError.unsupportedSubject
        }

        let primaryObject = valuationResponse.primaryObject
        let make = primaryObject?.make ?? primaryObject?.brand ?? primaryObject?.manufacturer
        let model = primaryObject?.model ?? primaryObject?.variant ?? primaryObject?.series
        let identifiedObject = [
            primaryObject?.objectType,
            primaryObject?.category,
            primaryObject?.subcategory,
            make,
            model
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " ")

        let amount = valuationResponse.valuation?.resolvedEstimatedValue

        guard !identifiedObject.isEmpty,
              let amount else {
            throw ChatGPTError.parseError
        }

        return ObjectValuation(
            identifiedObject: identifiedObject,
            make: make,
            model: model,
            amount: amount
        )
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

    private static func dataURL(for data: Data) -> String? {
        guard let mediaType = mediaType(for: data) else { return nil }
        return "data:\(mediaType);base64,\(data.base64EncodedString())"
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

private struct ResponseRequest: Encodable {
    let model: String
    let input: String
    let instructions: String?
}

private struct VisionResponseRequest: Encodable {
    let model: String
    let input: [VisionInputMessage]
}

private struct VisionInputMessage: Encodable {
    let role: String
    let content: [VisionInputContent]
}

private enum VisionInputContent: Encodable {
    case text(String)
    case image(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let imageURL):
            try container.encode("input_image", forKey: .type)
            try container.encode(imageURL, forKey: .imageURL)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
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

private struct ValuationResponse: Decodable {
    let supported: Bool
    let primaryObject: ValuationPrimaryObject?
    let valuation: ValuationDetails?

    enum CodingKeys: String, CodingKey {
        case supported
        case primaryObject = "primary_object"
        case valuation
    }
}

private struct ValuationPrimaryObject: Decodable {
    let objectType: String?
    let category: String?
    let subcategory: String?
    let make: String?
    let brand: String?
    let manufacturer: String?
    let model: String?
    let variant: String?
    let series: String?

    enum CodingKeys: String, CodingKey {
        case objectType = "object_type"
        case category
        case subcategory
        case make
        case brand
        case manufacturer
        case model
        case variant
        case series
    }
}

private struct ValuationDetails: Decodable {
    let estimatedValueSingle: FlexibleDouble?
    let estimatedValueRange: ValuationRange?

    enum CodingKeys: String, CodingKey {
        case estimatedValueSingle = "estimated_value_single"
        case estimatedValueRange = "estimated_value_range"
    }

    var resolvedEstimatedValue: Double? {
        if let estimatedValueSingle {
            return estimatedValueSingle.value
        }
        if let estimatedValueRange,
           let min = estimatedValueRange.min?.value,
           let max = estimatedValueRange.max?.value {
            return (min + max) / 2
        }
        return nil
    }
}

private struct ValuationRange: Decodable {
    let min: FlexibleDouble?
    let max: FlexibleDouble?
}

private struct FlexibleDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
            return
        }

        if let intValue = try? container.decode(Int.self) {
            value = Double(intValue)
            return
        }

        if let stringValue = try? container.decode(String.self),
           let parsed = Double(stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
            value = parsed
            return
        }

        throw DecodingError.typeMismatch(
            Double.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a numeric value")
        )
    }
}

enum ChatGPTError: LocalizedError, Equatable {
    case missingAPIKey
    case missingPhotos
    case invalidResponse
    case apiError(statusCode: Int)
    case parseError
    case unsupportedSubject

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing from app configuration."
        case .missingPhotos:
            return "Add at least one photo to calculate a valuation."
        case .invalidResponse:
            return "The ChatGPT service returned an invalid response."
        case .apiError(let statusCode):
            return "OpenAI API request failed with status code \(statusCode)."
        case .parseError:
            return "Could not parse ChatGPT response."
        case .unsupportedSubject:
            return "Valuation is only available for non-living objects."
        }
    }
}
