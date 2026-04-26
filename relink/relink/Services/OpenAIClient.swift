import Foundation

final class OpenAIClient {
    static let shared = OpenAIClient()

    private let baseURL = URL(string: "https://api.openai.com/v1")!

    private var apiKey: String? {
        func normalize(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return normalize(ProcessInfo.processInfo.environment["OPENAI_API_KEY"])
            ?? normalize(Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String)
    }

    func transcribeAudio(fileURL: URL, model: String = "whisper-1") async throws -> String {
        guard let apiKey else { throw OpenAIError.missingAPIKey }

        var request = URLRequest(url: baseURL.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        var body = Data()
        body.appendFormField(named: "model", value: model, boundary: boundary)
        body.appendFileField(
            named: "file",
            filename: fileURL.lastPathComponent,
            mimeType: "audio/m4a",
            fileData: audioData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(WhisperResponse.self, from: data).text
    }

    func chatText(model: String, system: String, user: String) async throws -> String {
        let response = try await chat(model: model, messages: [
            .init(role: "system", content: system),
            .init(role: "user", content: user),
        ], responseFormat: nil)

        return response.choices.first?.message.content ?? ""
    }

    func chatJSON(model: String, system: String, user: String) async throws -> [String: Any] {
        let response = try await chat(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user),
            ],
            responseFormat: .init(type: "json_object")
        )

        let content = response.choices.first?.message.content ?? "{}"
        let data = content.data(using: .utf8) ?? Data("{}".utf8)
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    private func chat(model: String, messages: [ChatMessage], responseFormat: ResponseFormat?) async throws -> ChatResponse {
        guard let apiKey else { throw OpenAIError.missingAPIKey }

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ChatRequest(model: model, messages: messages, responseFormat: responseFormat)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.badStatus(http.statusCode, message)
        }
    }
}

enum OpenAIError: Error {
    case missingAPIKey
    case badStatus(Int, String)
}

extension OpenAIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing OPENAI_API_KEY (set it in the app scheme env vars)."
        case let .badStatus(code, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "OpenAI API error (HTTP \(code))."
            }
            return "OpenAI API error (HTTP \(code)): \(trimmed)"
        }
    }
}

private struct WhisperResponse: Codable {
    let text: String
}

private struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ResponseFormat: Codable {
    let type: String
}

private struct ChatResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String?
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(string.data(using: .utf8)!)
    }

    mutating func appendFormField(named name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendFileField(
        named name: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
}
