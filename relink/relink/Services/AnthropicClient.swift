import Foundation

final class AnthropicClient {
    static let shared = AnthropicClient()

    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let anthropicVersion = "2023-06-01"

    private var apiKey: String? {
        func normalize(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return normalize(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"])
            ?? normalize(Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String)
    }

    func chatText(model: String, system: String, user: String, maxTokens: Int = 800) async throws -> String {
        let response = try await messages(
            model: model,
            system: system,
            user: user,
            maxTokens: maxTokens
        )

        return response.content
            .compactMap { $0.text }
            .joined()
    }

    func chatJSON(model: String, system: String, user: String, maxTokens: Int = 800) async throws -> [String: Any] {
        let text = try await chatText(model: model, system: system, user: user, maxTokens: maxTokens)
        let data = text.data(using: .utf8) ?? Data("{}".utf8)
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    private func messages(model: String, system: String, user: String, maxTokens: Int) async throws -> MessagesResponse {
        guard let apiKey else { throw AnthropicError.missingAPIKey }

        var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = MessagesRequest(
            model: model,
            maxTokens: maxTokens,
            system: system,
            messages: [
                .init(role: "user", content: user)
            ]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(MessagesResponse.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicError.badStatus(http.statusCode, message)
        }
    }
}

enum AnthropicError: Error {
    case missingAPIKey
    case badStatus(Int, String)
}

extension AnthropicError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing ANTHROPIC_API_KEY (set it in the app scheme env vars)."
        case let .badStatus(code, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Anthropic API error (HTTP \(code))."
            }
            return "Anthropic API error (HTTP \(code)): \(trimmed)"
        }
    }
}

private struct MessagesRequest: Codable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }

    struct Message: Codable {
        let role: String
        let content: String
    }
}

private struct MessagesResponse: Codable {
    let content: [ContentBlock]

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}
