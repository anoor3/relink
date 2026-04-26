import Foundation

struct Nudge: Identifiable, Codable, Equatable {
    var id: String { person.id }

    let person: Person
    let score: Int
    let reason: String
}

