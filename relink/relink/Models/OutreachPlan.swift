import Foundation

struct OutreachPlan: Codable, Equatable, Hashable {
    let createdAt: Date
    let guidance: String?
    var items: [OutreachPlanItem]

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case guidance
        case items
    }
}

struct OutreachPlanItem: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let sendAt: Date
    let subject: String
    let body: String
    var agentMailDraftID: String?
    var agentMailThreadID: String?
    var agentMailMessageID: String?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sendAt = "send_at"
        case subject
        case body
        case agentMailDraftID = "agentmail_draft_id"
        case agentMailThreadID = "agentmail_thread_id"
        case agentMailMessageID = "agentmail_message_id"
        case status
    }
}
