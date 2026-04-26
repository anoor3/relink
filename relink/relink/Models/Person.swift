import Foundation

struct Person: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var userID: String?

    var name: String
    var company: String?
    var role: String?

    var topicsDiscussed: [String]?
    var personalDetails: [String]?
    var signals: [String]?
    var sentiment: String?
    var followUpIntent: String?
    var relationshipStrength: Int?
    var tags: [String]?

    var email: String?
    var phoneNumber: String?
    var linkedInURL: String?

    var photoFilename: String?

    var galleryFilenames: [String]?

    var contactIdentifier: String?

    var lastContact: Date?
    var createdAt: Date?

    var interactions: [Interaction]?

    var outreachPlan: OutreachPlan?

    var daysSinceContact: Int {
        guard let lastContact else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastContact, to: Date()).day ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case company
        case role
        case topicsDiscussed = "topics_discussed"
        case personalDetails = "personal_details"
        case signals
        case sentiment
        case followUpIntent = "follow_up_intent"
        case relationshipStrength = "relationship_strength"
        case tags
        case email
        case phoneNumber = "phone_number"
        case linkedInURL = "linkedin_url"
        case photoFilename = "photo_filename"
        case galleryFilenames = "gallery_filenames"
        case contactIdentifier = "contact_identifier"
        case lastContact = "last_contact"
        case createdAt = "created_at"
        case interactions
        case outreachPlan = "outreach_plan"
    }
}
