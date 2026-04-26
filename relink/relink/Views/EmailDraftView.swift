import SwiftUI

struct EmailDraftView: View {
    let draft: EmailDraft
    let person: Person

    @Environment(\.dismiss) private var dismiss
    @State private var subject: String
    @State private var emailBody: String
    @State private var toEmail: String
    @State private var isSending = false
    @State private var errorMessage: String?

    @State private var guidance = ""
    @State private var isGenerating = false
    @State private var showGuidance = false

    init(draft: EmailDraft, person: Person) {
        self.draft = draft
        self.person = person
        _subject = State(initialValue: draft.subject)
        _emailBody = State(initialValue: draft.body)
        _toEmail = State(initialValue: person.email ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Draft")
                            .font(.system(size: 22, weight: .bold))
                            .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("To:  \(person.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            TextField("email", text: $toEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            TextField("Subject", text: $subject)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Body")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            TextEditor(text: $emailBody)
                                .frame(minHeight: 260)
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }

                        Text("This will be sent from your Relink agent inbox.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await regenerate() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(isGenerating ? "Working..." : "Regenerate")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isGenerating)

                    Button(isSending ? "Sending..." : "Approve & Send") {
                        Task { await send() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(isSending || toEmail.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                .overlay(alignment: .top) { Divider() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showGuidance = true
                    } label: {
                        Image(systemName: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showGuidance) {
                DraftPromptView(person: person, guidance: $guidance) {
                    Task { await regenerate() }
                }
            }
        }
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await APIClient.shared.sendEmail(personID: person.id, toEmail: toEmail, subject: subject, body: emailBody)
            dismiss()
        } catch {
            errorMessage = "Failed to send: \(error.localizedDescription)"
        }
    }

    private func regenerate() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let fresh = try await APIClient.shared.draftEmail(personID: person.id, guidance: guidance)
            subject = fresh.subject
            emailBody = fresh.body
        } catch {
            errorMessage = "Failed to generate: \(error.localizedDescription)"
        }
    }
}

#Preview {
    EmailDraftView(draft: EmailDraft(subject: "Quick catch-up", body: "Hey — want to reconnect?"), person: Person(id: "p1", userID: "user_1", name: "James", company: "Acme", role: "Designer", topicsDiscussed: [], personalDetails: [], signals: [], sentiment: "warm", followUpIntent: nil, relationshipStrength: 6, tags: ["design"], email: "james@example.com", lastContact: Date(), createdAt: Date(), interactions: []))
}
