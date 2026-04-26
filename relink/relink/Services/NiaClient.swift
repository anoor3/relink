import Foundation

final class NiaClient {
    static let shared = NiaClient()

    private let defaultBaseURL = URL(string: "https://api.trynia.ai/v1")!

    private var baseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["NIA_BASE_URL"],
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        return defaultBaseURL
    }

    private var apiKey: String? {
        func normalize(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return normalize(ProcessInfo.processInfo.environment["NIA_API_KEY"])
            ?? normalize(Bundle.main.object(forInfoDictionaryKey: "NIA_API_KEY") as? String)
    }

    var isConfigured: Bool { apiKey != nil }

    /// Best-effort: saves a person profile to Nia so semantic search can find them.
    func savePersonContext(person: Person) async throws {
        guard let apiKey else { throw NiaError.missingAPIKey }

        // Endpoint shape follows the project plan doc. If your Nia account uses a different endpoint,
        // set NIA_BASE_URL to point at it.
        let url = baseURL.appendingPathComponent("contexts/save")

        let summary = "\(person.role ?? "") at \(person.company ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any] = [
            "name": person.name,
            "summary": summary,
            "content": [
                "type": "relink_person",
                "person": person.toNiaPayload(),
            ],
            "memory_type": "episodic",
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    /// Semantic search over saved contexts.
    func semanticSearch(query: String, limit: Int = 10) async throws -> [[String: Any]] {
        guard let apiKey else { throw NiaError.missingAPIKey }

        let url = baseURL.appendingPathComponent("contexts/semantic")
        let payload: [String: Any] = [
            "query": query,
            "limit": limit,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let obj = try JSONSerialization.jsonObject(with: data)
        // Nia responses vary; try common container keys.
        if let dict = obj as? [String: Any] {
            if let items = dict["contexts"] as? [[String: Any]] { return items }
            if let items = dict["results"] as? [[String: Any]] { return items }
            if let items = dict["data"] as? [[String: Any]] { return items }
        }
        if let items = obj as? [[String: Any]] { return items }
        return []
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw NiaError.badStatus(http.statusCode, message)
        }
    }
}

enum NiaError: Error {
    case missingAPIKey
    case badStatus(Int, String)
}

extension NiaError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing NIA_API_KEY (set it in scheme env vars or Info.plist)."
        case let .badStatus(code, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Nia API error (HTTP \(code))."
            }
            return "Nia API error (HTTP \(code)): \(trimmed)"
        }
    }
}

private extension Person {
    func toNiaPayload() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "company": company as Any,
            "role": role as Any,
            "tags": tags ?? [],
            "topics_discussed": topicsDiscussed ?? [],
            "personal_details": personalDetails ?? [],
            "signals": signals ?? [],
            "sentiment": sentiment as Any,
            "follow_up_intent": followUpIntent as Any,
            "relationship_strength": relationshipStrength as Any,
            "email": email as Any,
            "phone_number": phoneNumber as Any,
            "linkedin_url": linkedInURL as Any,
            "days_since_contact": daysSinceContact,
        ]
    }
}

