import SwiftUI

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: person.name, size: 40, photoFilename: person.photoFilename)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(size: 15, weight: .semibold))

                Text("\(person.role ?? "Unknown") · \(person.company ?? "Unknown")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(person.daysSinceContact)d")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PersonRow(person: Person(id: "p1", userID: "user_1", name: "Sarah", company: "Acme", role: "PM", topicsDiscussed: [], personalDetails: [], signals: [], sentiment: nil, followUpIntent: nil, relationshipStrength: 5, tags: [], email: nil, lastContact: Date().addingTimeInterval(-60 * 60 * 24 * 12), createdAt: Date(), interactions: []))
}
