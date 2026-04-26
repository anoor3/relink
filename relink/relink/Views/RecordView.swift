import SwiftUI
import PhotosUI
import UIKit

struct RecordView: View {
    @EnvironmentObject private var tabRouter: TabRouter

    @StateObject private var recorder = AudioRecorder()
    @State private var isProcessing = false
    @State private var createdPerson: Person?
    @State private var errorMessage: String?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhoto: UIImage?
    @State private var showPhotoPicker = false

    private let userID = "user_1"

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 18) {
                    title
                        .padding(.top, 10)

                    Spacer()

                    errorBanner

                    recordOrb
                        .contentShape(Circle())
                        .gesture(recordGesture)

                    instructions

                    attachButton
                        .padding(.horizontal, 18)
                        .padding(.top, 6)

                    attachedPhotoPreview

                    Spacer()
                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        tabRouter.selectedTab = .home
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .navigationDestination(item: $createdPerson) { person in
                PersonCardView(person: person)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else {
                    selectedPhoto = nil
                    return
                }

                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedPhoto = image
                        }
                    }
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.black, Color.purple.opacity(0.6), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var title: some View {
        VStack(spacing: 6) {
            Text("Record about")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            Text("Someone New")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var errorBanner: some View {
        Group {
            if let message = (errorMessage ?? recorder.errorMessage) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
    }

    private var recordOrb: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(recorder.isRecording ? 0.35 : 0.22))
                .frame(width: 240, height: 240)
                .blur(radius: 0.5)
                .animation(.easeInOut(duration: 0.18), value: recorder.isRecording)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.95), Color.purple.opacity(0.65)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 160
                    )
                )
                .frame(width: 164, height: 164)

            VStack(spacing: 10) {
                Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var statusText: String {
        if isProcessing { return "Processing..." }
        return recorder.isRecording ? "Recording" : "Ready"
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isProcessing else { return }
                if !recorder.isRecording {
                    errorMessage = nil
                    _ = recorder.startRecording()
                }
            }
            .onEnded { _ in
                guard !isProcessing else { return }
                if let url = recorder.stopRecording() {
                    Task { await processAudio(url: url) }
                } else {
                    errorMessage = recorder.errorMessage
                }
            }
    }

    private var instructions: some View {
        VStack(spacing: 6) {
            Text(recorder.isRecording ? "Release to process" : "Hold to record")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
            Text(recorder.isRecording ? "" : "Release to stop")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var attachButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                Text("Add photo or business card")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var attachedPhotoPreview: some View {
        Group {
            if let selectedPhoto {
                HStack(spacing: 12) {
                    Image(uiImage: selectedPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photo attached")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Button("Remove") {
                            self.selectedPhoto = nil
                            selectedPhotoItem = nil
                        }
                        .font(.system(size: 12, weight: .medium))
                         .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }
        }
    }

    private func processAudio(url: URL) async {
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            var person = try await APIClient.shared.addPerson(audioURL: url, userID: userID)

            if let selectedPhoto {
                do {
                    let filename = try ImageStore.savePersonPhoto(selectedPhoto, personID: person.id)
                    person.photoFilename = filename
                    LocalStore.shared.upsertPerson(person)
                } catch {
                    // Non-fatal: keep the person, drop the photo
                }
            }

            createdPerson = LocalStore.shared.getPerson(id: person.id) ?? person
        } catch {
            errorMessage = "Failed to process memo: \(error.localizedDescription)"
        }
    }
}

#Preview {
    RecordView()
        .environmentObject(TabRouter())
}
