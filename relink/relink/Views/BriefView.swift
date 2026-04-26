import SwiftUI

struct BriefView: View {
    let person: Person

    @State private var brief = ""
    @State private var isLoading = true
    @State private var emailDraft: EmailDraft?
    @State private var showEmailDraft = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Brief me on")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(person.name)
                        .font(.system(size: 28, weight: .bold))
                }
                .padding(.horizontal)
                .padding(.top, 14)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Executive Summary")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(brief.isEmpty ? "" : brief)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                    .padding(.top, 6)
                }

                Button {
                    Task { await draftEmail() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                        Text("Draft Message with AI")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal)
                .padding(.top, 6)
            }
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.18), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBrief() }
        .sheet(isPresented: $showEmailDraft) {
            if let emailDraft {
                EmailDraftView(draft: emailDraft, person: person)
            }
        }
    }

    private func loadBrief() async {
        isLoading = true
        defer { isLoading = false }
        brief = (try? await APIClient.shared.getBrief(personID: person.id)) ?? ""
    }

    private func draftEmail() async {
        emailDraft = try? await APIClient.shared.draftEmail(personID: person.id)
        showEmailDraft = emailDraft != nil
    }
}

#Preview {
    NavigationStack {
        BriefView(
            person: Person(
                id: "p_1",
                userID: "user_1",
                name: "Rohan Mehta",
                company: "FinEdge",
                role: "Co-founder",
                topicsDiscussed: [],
                personalDetails: [],
                signals: [],
                sentiment: "warm",
                followUpIntent: nil,
                relationshipStrength: 7,
                tags: ["fintech"],
                email: "rohan@example.com",
                lastContact: Date().addingTimeInterval(-60 * 60 * 24 * 68),
                createdAt: Date(),
                interactions: []
            )
        )
    }
}
