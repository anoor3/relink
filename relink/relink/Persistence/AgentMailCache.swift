import Foundation

final class AgentMailCache {
    static let shared = AgentMailCache()

    private let decoder: JSONDecoder = {
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
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func loadThreads() -> [AgentMailThreadItem] {
        do {
            let data = try Data(contentsOf: fileURL)
            let response = try decoder.decode(AgentMailListThreadsResponse.self, from: data)
            return response.threads
        } catch {
            return []
        }
    }

    func saveThreads(_ threads: [AgentMailThreadItem]) {
        do {
            let response = AgentMailListThreadsResponse(count: threads.count, threads: threads, limit: nil, nextPageToken: nil)
            let data = try encoder.encode(response)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // best-effort cache
        }
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("relink").appendingPathComponent("agentmail_threads.json")
    }
}

private extension ISO8601DateFormatter {
    static let agentMail: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

