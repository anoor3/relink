import SwiftUI

struct InteractionRow: View {
    let interaction: Interaction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(interaction.type.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if let createdAt = interaction.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Text(interaction.content)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineLimit(4)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

#Preview {
    InteractionRow(interaction: Interaction(id: "i1", personID: "p1", type: "voice_memo", content: "Met at a meetup; talked about voice agents.", createdAt: Date()))
}

