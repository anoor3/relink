import SwiftUI

struct DraftPromptView: View {
    let person: Person
    @Binding var guidance: String
    let onGenerate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = AudioRecorder()

    @State private var isTranscribing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tell AI what you want to say")
                        .font(.system(size: 16, weight: .semibold))

                    Text("This will guide the subject + body for \(person.name).")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: $guidance)
                    .frame(minHeight: 180)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button {
                        toggleVoiceNote()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            Text(isTranscribing ? "Transcribing..." : (recorder.isRecording ? "Stop" : "Voice"))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isTranscribing)

                    Button("Generate") {
                        onGenerate()
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.top, 2)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .navigationTitle("AI Guidance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func toggleVoiceNote() {
        errorMessage = nil

        if recorder.isRecording {
            guard let url = recorder.stopRecording() else {
                errorMessage = recorder.errorMessage
                return
            }
            Task { await transcribePrompt(url: url) }
        } else {
            _ = recorder.startRecording()
            if let msg = recorder.errorMessage {
                errorMessage = msg
            }
        }
    }

    private func transcribePrompt(url: URL) async {
        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let text = try await OpenAIClient.shared.transcribeAudio(fileURL: url)
            guidance = [guidance, text]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    DraftPromptView(
        person: Person(
            id: "p_1",
            userID: "user_1",
            name: "Jordan",
            company: "FinEdge",
            role: "Co-founder",
            topicsDiscussed: [],
            personalDetails: [],
            signals: [],
            sentiment: "warm",
            followUpIntent: nil,
            relationshipStrength: 8,
            tags: ["Fintech"],
            email: "jordan@example.com",
            phoneNumber: nil,
            linkedInURL: nil,
            photoFilename: nil,
            lastContact: Date(),
            createdAt: Date(),
            interactions: []
        ),
        guidance: .constant("Mention the demo day chat and ask for a catch-up."),
        onGenerate: {}
    )
}

