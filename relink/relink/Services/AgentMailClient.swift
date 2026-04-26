import Foundation

final class AgentMailClient {
    static let shared = AgentMailClient()

    private let baseURL = URL(string: "https://api.agentmail.to/v0")!
    private let inboxIDKey = "relink_agentmail_inbox_id"
    private let inboxEmailKey = "relink_agentmail_inbox_email"

    private var apiKey: String? {
        func normalize(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return normalize(ProcessInfo.processInfo.environment["AGENTMAIL_API_KEY"])
            ?? normalize(Bundle.main.object(forInfoDictionaryKey: "AGENTMAIL_API_KEY") as? String)
    }

    var isConfigured: Bool { apiKey != nil }

    var activeInboxID: String? {
        UserDefaults.standard.string(forKey: inboxIDKey)
    }

    func setActiveInbox(_ inbox: AgentMailInbox) {
        cacheInbox(id: inbox.inboxID, email: inbox.email)
    }

    func clearActiveInbox() {
        UserDefaults.standard.removeObject(forKey: inboxIDKey)
        UserDefaults.standard.removeObject(forKey: inboxEmailKey)
    }

    func ensureInbox(displayName: String) async throws -> AgentMailInbox {
        if let cached = cachedInbox() {
            return cached
        }

        let list = try await listInboxes(limit: 50)
        if list.inboxes.count == 1, let only = list.inboxes.first {
            cacheInbox(id: only.inboxID, email: only.email)
            return only
        }

        if list.inboxes.count > 1 {
            throw AgentMailError.inboxSelectionRequired
        }

        let created = try await createInbox(displayName: displayName)
        cacheInbox(id: created.inboxID, email: created.email)
        return created
    }

    func getCachedInboxEmail() -> String? {
        UserDefaults.standard.string(forKey: inboxEmailKey)
    }

    func listThreads(inboxID: String, limit: Int = 20) async throws -> AgentMailListThreadsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("inboxes/\(inboxID)/threads"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var request = try authorizedRequest(url: components.url!, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailListThreadsResponse.self, from: data)
    }

    func getThread(inboxID: String, threadID: String) async throws -> AgentMailThread {
        let url = baseURL.appendingPathComponent("inboxes/\(inboxID)/threads/\(threadID)")
        let request = try authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailThread.self, from: data)
    }

    func sendMessage(inboxID: String, to: [String], subject: String, text: String) async throws -> AgentMailSendMessageResponse {
        let url = baseURL.appendingPathComponent("inboxes/\(inboxID)/messages/send")
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AgentMailSendMessageRequest(to: to, subject: subject, text: text))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailSendMessageResponse.self, from: data)
    }

    func createDraft(
        inboxID: String,
        to: [String],
        subject: String,
        text: String,
        sendAt: Date?,
        clientID: String?,
        labels: [String] = []
    ) async throws -> AgentMailDraft {
        let url = baseURL.appendingPathComponent("inboxes/\(inboxID)/drafts")
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AgentMailCreateDraftRequest(
            labels: labels.isEmpty ? nil : labels,
            to: to,
            subject: subject,
            text: text,
            sendAt: sendAt?.agentMailISO8601,
            clientID: clientID
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailDraft.self, from: data)
    }

    func getDraft(inboxID: String, draftID: String) async throws -> AgentMailDraft {
        let url = baseURL.appendingPathComponent("inboxes/\(inboxID)/drafts/\(draftID)")
        let request = try authorizedRequest(url: url, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailDraft.self, from: data)
    }

    func deleteDraft(inboxID: String, draftID: String) async throws {
        let url = baseURL.appendingPathComponent("inboxes/\(inboxID)/drafts/\(draftID)")
        let request = try authorizedRequest(url: url, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        // DELETE returns 200 with empty body in most APIs; AgentMail docs show 200.
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AgentMailError.badStatus(http.statusCode, "")
        }
    }

    func listMessages(inboxID: String, limit: Int = 50, labels: [String]? = nil) async throws -> AgentMailListMessagesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("inboxes/\(inboxID)/messages"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let labels, !labels.isEmpty {
            // AgentMail accepts repeated `labels` query params.
            for label in labels {
                items.append(URLQueryItem(name: "labels", value: label))
            }
        }
        components.queryItems = items

        let request = try authorizedRequest(url: components.url!, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailListMessagesResponse.self, from: data)
    }

    func sendDraft(inboxID: String, draftID: String) async throws -> AgentMailSendMessageResponse {
        let url = baseURL.appendingPathComponent("inboxes/\(inboxID)/drafts/\(draftID)/send")
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailSendMessageResponse.self, from: data)
    }

    // MARK: - Inboxes

    func listInboxes(limit: Int = 10) async throws -> AgentMailListInboxesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("inboxes"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]

        let request = try authorizedRequest(url: components.url!, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailListInboxesResponse.self, from: data)
    }

    func createInbox(displayName: String) async throws -> AgentMailInbox {
        let url = baseURL.appendingPathComponent("inboxes")
        var request = try authorizedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AgentMailCreateInboxRequest(displayName: displayName))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(AgentMailInbox.self, from: data)
    }

    // MARK: - Helpers

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.agentMail.date(from: value) {
                return date
            }
            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }

    private func authorizedRequest(url: URL, method: String) throws -> URLRequest {
        guard let apiKey else { throw AgentMailError.missingAPIKey }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw AgentMailError.badStatus(http.statusCode, message)
        }
    }

    private func cachedInbox() -> AgentMailInbox? {
        guard let inboxID = UserDefaults.standard.string(forKey: inboxIDKey), !inboxID.isEmpty else {
            return nil
        }

        let email = UserDefaults.standard.string(forKey: inboxEmailKey) ?? ""
        return AgentMailInbox(
            podID: "",
            inboxID: inboxID,
            email: email,
            displayName: nil,
            clientID: nil,
            updatedAt: nil,
            createdAt: nil
        )
    }

    private func cacheInbox(id: String, email: String) {
        UserDefaults.standard.set(id, forKey: inboxIDKey)
        UserDefaults.standard.set(email, forKey: inboxEmailKey)
    }
}

enum AgentMailError: Error {
    case missingAPIKey
    case inboxSelectionRequired
    case badStatus(Int, String)
}

extension AgentMailError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing AGENTMAIL_API_KEY (set it in the app scheme env vars or Info.plist)."
        case .inboxSelectionRequired:
            return "Multiple AgentMail inboxes found. Choose one in Inbox → filter icon."
        case let .badStatus(code, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "AgentMail API error (HTTP \(code))."
            }
            return "AgentMail API error (HTTP \(code)): \(trimmed)"
        }
    }
}

private extension ISO8601DateFormatter {
    static let agentMail: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Models

struct AgentMailInbox: Codable {
    let podID: String
    let inboxID: String
    let email: String
    let displayName: String?
    let clientID: String?
    let updatedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case podID = "pod_id"
        case inboxID = "inbox_id"
        case email
        case displayName = "display_name"
        case clientID = "client_id"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}

struct AgentMailListInboxesResponse: Codable {
    let count: Int
    let inboxes: [AgentMailInbox]
    let limit: Int?
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case count
        case inboxes
        case limit
        case nextPageToken = "next_page_token"
    }
}

struct AgentMailCreateInboxRequest: Codable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

struct AgentMailThreadItem: Identifiable, Codable {
    var id: String { threadID }

    let inboxID: String
    let threadID: String
    let labels: [String]
    let timestamp: Date
    let senders: [String]
    let recipients: [String]
    let subject: String?
    let preview: String?
    let lastMessageID: String
    let messageCount: Int
    let updatedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case inboxID = "inbox_id"
        case threadID = "thread_id"
        case labels
        case timestamp
        case senders
        case recipients
        case subject
        case preview
        case lastMessageID = "last_message_id"
        case messageCount = "message_count"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}

struct AgentMailListThreadsResponse: Codable {
    let count: Int
    let threads: [AgentMailThreadItem]
    let limit: Int?
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case count
        case threads
        case limit
        case nextPageToken = "next_page_token"
    }
}

struct AgentMailMessage: Identifiable, Codable {
    var id: String { messageID }

    let inboxID: String
    let threadID: String
    let messageID: String
    let labels: [String]
    let timestamp: Date
    let from: String
    let to: [String]
    let subject: String?
    let preview: String?
    let text: String?
    let extractedText: String?

    enum CodingKeys: String, CodingKey {
        case inboxID = "inbox_id"
        case threadID = "thread_id"
        case messageID = "message_id"
        case labels
        case timestamp
        case from
        case to
        case subject
        case preview
        case text
        case extractedText = "extracted_text"
    }
}

struct AgentMailThread: Codable, Identifiable {
    var id: String { threadID }

    let inboxID: String
    let threadID: String
    let labels: [String]
    let timestamp: Date
    let senders: [String]
    let recipients: [String]
    let subject: String?
    let preview: String?
    let lastMessageID: String
    let messageCount: Int
    let updatedAt: Date
    let createdAt: Date
    let messages: [AgentMailMessage]

    enum CodingKeys: String, CodingKey {
        case inboxID = "inbox_id"
        case threadID = "thread_id"
        case labels
        case timestamp
        case senders
        case recipients
        case subject
        case preview
        case lastMessageID = "last_message_id"
        case messageCount = "message_count"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case messages
    }
}

struct AgentMailSendMessageRequest: Codable {
    let to: [String]
    let subject: String
    let text: String
}

struct AgentMailSendMessageResponse: Codable {
    let messageID: String
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case threadID = "thread_id"
    }
}

struct AgentMailDraft: Codable {
    let inboxID: String
    let draftID: String
    let clientID: String?
    let labels: [String]
    let sendAt: Date?
    let sendStatus: String?
    let to: [String]?
    let subject: String?
    let text: String?
    let updatedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case inboxID = "inbox_id"
        case draftID = "draft_id"
        case clientID = "client_id"
        case labels
        case sendAt = "send_at"
        case sendStatus = "send_status"
        case to
        case subject
        case text
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}

struct AgentMailCreateDraftRequest: Codable {
    let labels: [String]?
    let to: [String]
    let subject: String
    let text: String
    let sendAt: String?
    let clientID: String?

    enum CodingKeys: String, CodingKey {
        case labels
        case to
        case subject
        case text
        case sendAt = "send_at"
        case clientID = "client_id"
    }
}

struct AgentMailMessageItem: Identifiable, Codable {
    var id: String { messageID }

    let inboxID: String
    let threadID: String
    let messageID: String
    let labels: [String]
    let timestamp: Date
    let from: String?
    let to: [String]?
    let subject: String?
    let preview: String?

    enum CodingKeys: String, CodingKey {
        case inboxID = "inbox_id"
        case threadID = "thread_id"
        case messageID = "message_id"
        case labels
        case timestamp
        case from
        case to
        case subject
        case preview
    }
}

struct AgentMailListMessagesResponse: Codable {
    let count: Int
    let messages: [AgentMailMessageItem]
    let limit: Int?
    let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case count
        case messages
        case limit
        case nextPageToken = "next_page_token"
    }
}

private extension Date {
    var agentMailISO8601: String {
        ISO8601DateFormatter.agentMailNoFraction.string(from: self)
    }
}

private extension ISO8601DateFormatter {
    static let agentMailNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
