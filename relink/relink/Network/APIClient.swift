import Foundation
import UIKit

final class APIClient {
    static let shared = APIClient()

    private let openAI = OpenAIClient.shared
    private let agentMail = AgentMailClient.shared
    private let nia = NiaClient.shared
    private let store = LocalStore.shared

    func addPerson(audioURL: URL, userID: String) async throws -> Person {
        let transcript = try await openAI.transcribeAudio(fileURL: audioURL)

        let agentModel = ProcessInfo.processInfo.environment["RELINK_OPENAI_AGENT_MODEL"] ?? "gpt-4o-mini"
        let extracted = try await openAI.chatJSON(model: agentModel, system: Prompts.extractionSystem, user: transcript)

        let personID = "p_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let now = Date()

        let person = Person(
            id: personID,
            userID: userID,
            name: (extracted["name"] as? String) ?? "Unknown",
            company: extracted["company"] as? String,
            role: extracted["role"] as? String,
            topicsDiscussed: extracted["topics_discussed"] as? [String],
            personalDetails: extracted["personal_details"] as? [String],
            signals: extracted["signals"] as? [String],
            sentiment: extracted["sentiment"] as? String,
            followUpIntent: extracted["follow_up_intent"] as? String,
            relationshipStrength: extracted["relationship_strength"] as? Int,
            tags: extracted["tags"] as? [String],
            email: nil,
            lastContact: now,
            createdAt: now,
            interactions: []
        )

        store.upsertPerson(person)

        let interaction = Interaction(
            id: "i_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            personID: personID,
            type: "voice_memo",
            content: transcript,
            createdAt: now
        )
        store.addInteraction(personID: personID, interaction: interaction)

        if nia.isConfigured {
            Task {
                try? await nia.savePersonContext(person: store.getPerson(id: personID) ?? person)
            }
        }

        return store.getPerson(id: personID) ?? person
    }

    func getPersons(userID: String) async throws -> [Person] {
        store.getPersons(userID: userID)
    }

    func getBrief(personID: String) async throws -> String {
        guard let person = store.getPerson(id: personID) else { return "" }

        let agentModel = ProcessInfo.processInfo.environment["RELINK_OPENAI_AGENT_MODEL"] ?? "gpt-4o-mini"
        let payload: [String: Any] = [
            "profile": person.toAgentPayload(),
            "interactions": (person.interactions ?? []).map { $0.toAgentPayload() },
            "days_since_contact": person.daysSinceContact,
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        let content = String(data: json, encoding: .utf8) ?? ""
        return try await openAI.chatText(model: agentModel, system: Prompts.briefingSystem, user: content)
    }

    func getNudges(userID: String) async throws -> [Nudge] {
        let persons = store.getPersons(userID: userID)

        func score(_ person: Person) -> Int {
            let days = person.daysSinceContact
            let base = Int(min(100, (Double(days) / 30.0) * 100.0))
            let signalBoost = (person.signals ?? []).count * 10
            let strengthBoost = (person.relationshipStrength ?? 5) * 5
            return min(base + signalBoost + strengthBoost, 100)
        }

        let sorted = persons
            .map { (person: $0, score: score($0)) }
            .sorted { $0.score > $1.score }
            .prefix(3)

        return sorted.map { item in
            Nudge(
                person: item.person,
                score: item.score,
                reason: "It’s been a while — a quick, human reach-out would keep this relationship warm."
            )
        }
    }

    func draftEmail(personID: String, guidance: String? = nil) async throws -> EmailDraft {
        guard let person = store.getPerson(id: personID) else {
            return EmailDraft(subject: "", body: "")
        }

        let agentModel = ProcessInfo.processInfo.environment["RELINK_OPENAI_AGENT_MODEL"] ?? "gpt-4o-mini"
        let payload: [String: Any] = [
            "profile": person.toAgentPayload(),
            "interactions": (person.interactions ?? []).map { $0.toAgentPayload() },
            "user_guidance": guidance ?? "",
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        let content = String(data: json, encoding: .utf8) ?? ""
        let draftJSON = try await openAI.chatJSON(model: agentModel, system: Prompts.outreachSystem, user: content)

        return EmailDraft(
            subject: (draftJSON["subject"] as? String) ?? "",
            body: (draftJSON["body"] as? String) ?? ""
        )
    }

    private func mapNiaResultsToPeople(_ items: [[String: Any]], userID: String) -> [SearchResult] {
        let people = store.getPersons(userID: userID)
        let byID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })

        func extractPersonID(_ item: [String: Any]) -> String? {
            if let content = item["content"] as? [String: Any],
               let person = content["person"] as? [String: Any],
               let id = person["id"] as? String {
                return id
            }
            if let person = item["person"] as? [String: Any], let id = person["id"] as? String { return id }
            if let id = item["id"] as? String, id.hasPrefix("p_") || id.hasPrefix("p_demo") { return id }
            return nil
        }

        func extractReason(_ item: [String: Any]) -> String {
            if let reason = item["reason"] as? String { return reason }
            if let summary = item["summary"] as? String { return summary }
            return ""
        }

        var results: [SearchResult] = []
        for item in items.prefix(10) {
            guard let id = extractPersonID(item), let person = byID[id] else { continue }
            let reason = extractReason(item)
            results.append(SearchResult(person: person, reason: reason, outreachGuidance: ""))
        }

        return results
    }

    func generateOutreachPlan(personID: String, guidance: String? = nil) async throws -> OutreachPlan {
        guard var person = store.getPerson(id: personID) else {
            return OutreachPlan(createdAt: Date(), guidance: guidance, items: [])
        }

        let agentModel = ProcessInfo.processInfo.environment["RELINK_OPENAI_AGENT_MODEL"] ?? "gpt-4o-mini"
        let payload: [String: Any] = [
            "profile": person.toAgentPayload(),
            "interactions": (person.interactions ?? []).map { $0.toAgentPayload() },
            "days_since_contact": person.daysSinceContact,
            "user_guidance": guidance ?? "",
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        let content = String(data: json, encoding: .utf8) ?? ""

        let planJSON = try await openAI.chatJSON(model: agentModel, system: Prompts.planSystem, user: content)
        let touchpoints = (planJSON["touchpoints"] as? [[String: Any]]) ?? []

        let now = Date()
        let calendar = Calendar.current

        func parseTime(_ value: String?) -> (hour: Int, minute: Int)? {
            guard let value else { return nil }
            let parts = value.split(separator: ":").map { String($0) }
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return (hour, minute)
        }

        func ensureFuture(_ date: Date) -> Date {
            // AgentMail scheduled sends are more reliable with a little lead time.
            let minLead: TimeInterval = 90
            if date.timeIntervalSince(now) < minLead {
                let bumped = now.addingTimeInterval(minLead)
                // Round to the next minute.
                let seconds = calendar.component(.second, from: bumped)
                return calendar.date(byAdding: .second, value: 60 - seconds, to: bumped) ?? bumped
            }
            return date
        }

        var items: [OutreachPlanItem] = []
        items.reserveCapacity(touchpoints.count)

        for tp in touchpoints.prefix(3) {
            let days = (tp["send_in_days"] as? Int) ?? 0
            let time = parseTime(tp["send_time_local"] as? String)
            let subject = (tp["subject"] as? String) ?? ""
            let body = (tp["body"] as? String) ?? ""
            let id = "plan_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

            let baseDay = calendar.date(byAdding: .day, value: max(0, min(21, days)), to: now) ?? now
            let scheduledRaw: Date
            if let time {
                scheduledRaw = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: baseDay) ?? baseDay
            } else {
                scheduledRaw = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: baseDay) ?? baseDay
            }

            let scheduled = ensureFuture(scheduledRaw)

            items.append(
                OutreachPlanItem(
                    id: id,
                    sendAt: scheduled,
                    subject: subject,
                    body: body,
                    agentMailDraftID: nil,
                    agentMailThreadID: nil,
                    agentMailMessageID: nil,
                    status: nil
                )
            )
        }

        var plan = OutreachPlan(createdAt: now, guidance: guidance, items: items.sorted { $0.sendAt < $1.sendAt })

        // Optionally schedule in AgentMail as drafts.
        if agentMail.isConfigured, let toEmail = person.email, !toEmail.isEmpty {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await agentMail.ensureInbox(displayName: displayName)

            for idx in plan.items.indices {
                let item = plan.items[idx]
                let draft = try await agentMail.createDraft(
                    inboxID: inbox.inboxID,
                    to: [toEmail],
                    subject: item.subject,
                    text: item.body,
                    sendAt: item.sendAt,
                    clientID: item.id,
                    labels: ["relink", "plan", "plan:\(item.id)"]
                )
                plan.items[idx].agentMailDraftID = draft.draftID
                plan.items[idx].status = draft.sendStatus ?? "scheduled"
            }
        }

        person.outreachPlan = plan
        store.upsertPerson(person)
        return plan
    }

    struct SearchResult: Identifiable, Equatable {
        var id: String { person.id }
        let person: Person
        let reason: String
        let outreachGuidance: String
    }

    func searchPeople(userID: String, query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if nia.isConfigured {
            do {
                let niaItems = try await nia.semanticSearch(query: trimmed, limit: 10)
                let mapped = mapNiaResultsToPeople(niaItems, userID: userID)
                if !mapped.isEmpty {
                    return mapped
                }
            } catch {
                // fall back to on-device ranking
            }
        }

        let people = store.getPersons(userID: userID)
        if people.isEmpty { return [] }

        let agentModel = ProcessInfo.processInfo.environment["RELINK_OPENAI_AGENT_MODEL"] ?? "gpt-4o-mini"

        let payloadPeople: [[String: Any]] = people.prefix(120).map { person in
            [
                "id": person.id,
                "name": person.name,
                "company": person.company as Any,
                "role": person.role as Any,
                "tags": person.tags ?? [],
                "topics_discussed": person.topicsDiscussed ?? [],
                "personal_details": person.personalDetails ?? [],
                "signals": person.signals ?? [],
                "days_since_contact": person.daysSinceContact,
                "relationship_strength": person.relationshipStrength as Any,
            ]
        }

        let payload: [String: Any] = [
            "query": trimmed,
            "people": payloadPeople,
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        let content = String(data: json, encoding: .utf8) ?? ""

        let resultJSON = try await openAI.chatJSON(model: agentModel, system: Prompts.searchSystem, user: content)
        let results = (resultJSON["results"] as? [[String: Any]]) ?? []

        var mapped: [SearchResult] = []
        mapped.reserveCapacity(results.count)

        for item in results {
            guard let personID = item["person_id"] as? String else { continue }
            guard let person = store.getPerson(id: personID) else { continue }
            let reason = (item["reason"] as? String) ?? ""
            let guidance = (item["outreach_guidance"] as? String) ?? ""
            mapped.append(SearchResult(person: person, reason: reason, outreachGuidance: guidance))
        }

        return mapped
    }

    func draftTextMessage(personID: String, guidance: String? = nil) async throws -> TextMessageDraft {
        guard let person = store.getPerson(id: personID) else {
            return TextMessageDraft(body: "")
        }

        let agentModel = ProcessInfo.processInfo.environment["RELINK_OPENAI_AGENT_MODEL"] ?? "gpt-4o-mini"
        let payload: [String: Any] = [
            "profile": person.toAgentPayload(),
            "interactions": (person.interactions ?? []).map { $0.toAgentPayload() },
            "user_guidance": guidance ?? "",
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        let content = String(data: json, encoding: .utf8) ?? ""
        let draftJSON = try await openAI.chatJSON(model: agentModel, system: Prompts.textMessageSystem, user: content)
        let body = (draftJSON["body"] as? String) ?? ""
        return TextMessageDraft(body: body)
    }

    @MainActor
    func sendTextMessage(personID: String, toPhone: String, body: String) async throws {
        let createdAt = Date()
        let interaction = Interaction(
            id: "i_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            personID: personID,
            type: "sms_sent",
            content: body,
            createdAt: createdAt
        )
        store.addInteraction(personID: personID, interaction: interaction)

        guard let url = SMSURLBuilder.build(to: toPhone, body: body) else {
            throw APIError.invalidPhone
        }
        guard UIApplication.shared.canOpenURL(url) else {
            throw APIError.cannotOpenMessages
        }
        await UIApplication.shared.open(url)
    }

    @MainActor
    func sendEmail(personID: String, toEmail: String, subject: String, body: String) async throws {
        let createdAt = Date()
        let interaction = Interaction(
            id: "i_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(),
            personID: personID,
            type: "email_sent",
            content: "Subject: \(subject)",
            createdAt: createdAt
        )
        store.addInteraction(personID: personID, interaction: interaction)

        if agentMail.isConfigured {
            let displayName = UserDefaults.standard.string(forKey: "relink_user_name") ?? "Relink Agent"
            let inbox = try await agentMail.ensureInbox(displayName: displayName)
            _ = try await agentMail.sendMessage(inboxID: inbox.inboxID, to: [toEmail], subject: subject, text: body)
            return
        }

        guard let url = MailtoURLBuilder.build(to: toEmail, subject: subject, body: body) else {
            throw APIError.invalidEmail
        }
        guard UIApplication.shared.canOpenURL(url) else {
            throw APIError.cannotOpenMail
        }
        await UIApplication.shared.open(url)
    }
}

enum APIError: Error {
    case missingOpenAIKey
    case invalidEmail
    case invalidPhone
    case cannotOpenMail
    case cannotOpenMessages
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingOpenAIKey:
            return "Missing OPENAI_API_KEY (set it in the app scheme env vars)."
        case .invalidEmail:
            return "Invalid email address."
        case .invalidPhone:
            return "Invalid phone number."
        case .cannotOpenMail:
            return "Cannot open Mail app."
        case .cannotOpenMessages:
            return "Cannot open Messages app."
        }
    }
}

private enum MailtoURLBuilder {
    static func build(to: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

private enum SMSURLBuilder {
    static func build(to: String, body: String) -> URL? {
        let digits = to.filter { "+0123456789".contains($0) }
        guard !digits.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "sms"
        components.path = digits
        components.queryItems = [
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

private extension Person {
    func toAgentPayload() -> [String: Any] {
        [
            "id": id,
            "user_id": userID ?? "",
            "name": name,
            "company": company as Any,
            "role": role as Any,
            "topics_discussed": topicsDiscussed ?? [],
            "personal_details": personalDetails ?? [],
            "signals": signals ?? [],
            "sentiment": sentiment as Any,
            "follow_up_intent": followUpIntent as Any,
            "relationship_strength": relationshipStrength as Any,
            "tags": tags ?? [],
            "email": email as Any,
            "last_contact": (lastContact ?? Date()).iso8601String,
            "created_at": (createdAt ?? Date()).iso8601String,
        ]
    }
}

private extension Interaction {
    func toAgentPayload() -> [String: Any] {
        [
            "id": id,
            "person_id": personID,
            "type": type,
            "content": content,
            "created_at": (createdAt ?? Date()).iso8601String,
        ]
    }
}

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
