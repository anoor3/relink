import Foundation

struct Interaction: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let personID: String
    let type: String
    let content: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case personID = "person_id"
        case type
        case content
        case createdAt = "created_at"
    }
}
