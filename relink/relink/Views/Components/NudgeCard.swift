import SwiftUI

struct NudgeCard: View {
    let nudge: Nudge

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: nudge.person.name, size: 44, photoFilename: nudge.person.photoFilename)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nudge.person.name)
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(nudge.person.role ?? "Unknown") at \(nudge.person.company ?? "Unknown")")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    PriorityPill(daysSinceContact: nudge.person.daysSinceContact)
                }

                Text("Haven’t connected in \(nudge.person.daysSinceContact) days")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Text(nudge.reason)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
    }
}

private struct PriorityPill: View {
    let daysSinceContact: Int

    private var label: String {
        switch daysSinceContact {
        case 0..<30:
            return "Low"
        case 30..<75:
            return "Medium"
        default:
            return "High Priority"
        }
    }

    private var tint: Color {
        switch daysSinceContact {
        case 0..<30:
            return Color.green
        case 30..<75:
            return Color.orange
        default:
            return Color.red
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    NudgeCard(
        nudge: Nudge(
            person: Person(id: "p1", userID: "user_1", name: "Marcus", company: "FintechCo", role: "Founder", topicsDiscussed: [], personalDetails: [], signals: ["Going through something hard"], sentiment: "warm", followUpIntent: nil, relationshipStrength: 8, tags: ["fintech"], email: nil, lastContact: Date().addingTimeInterval(-60 * 60 * 24 * 91), createdAt: Date(), interactions: []),
            score: 92,
            reason: "It’s been a while and he signaled something sensitive — a check-in now would matter."
        )
    )
}
