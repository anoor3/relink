import SwiftUI

struct BriefBubble: View {
    let text: String
    let interactionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BRIEF")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.purple)
                Spacer()
                Text("\(interactionCount) memories")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(text)
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .padding(12)
        .background(Color.purple.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    BriefBubble(text: "You met David at demo day. He’s focused on AI infra, and you talked about enterprise adoption. A natural reconnect angle is sharing a concrete playbook and asking what he’s seeing lately.", interactionCount: 2)
}

