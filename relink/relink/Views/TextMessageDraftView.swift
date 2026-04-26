import SwiftUI

struct TextMessageDraftView: View {
    let draft: TextMessageDraft
    let person: Person

    @Environment(\.dismiss) private var dismiss
    @State private var bodyText: String
    @State private var toPhone: String
    @State private var isSending = false
    @State private var errorMessage: String?

    init(draft: TextMessageDraft, person: Person) {
        self.draft = draft
        self.person = person
        _bodyText = State(initialValue: draft.body)
        _toPhone = State(initialValue: person.phoneNumber ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Message")
                            .font(.system(size: 22, weight: .bold))
                            .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("To:  \(person.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            TextField("phone", text: $toPhone)
                                .keyboardType(.phonePad)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            TextEditor(text: $bodyText)
                                .frame(minHeight: 220)
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }

                        Text("Messages will open for you to confirm send.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                }

                Button(isSending ? "Opening..." : "Send via Messages") {
                    Task { await send() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(Color(.systemBackground))
                .overlay(alignment: .top) { Divider() }
                .disabled(isSending || toPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await APIClient.shared.sendTextMessage(personID: person.id, toPhone: toPhone, body: bodyText)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

