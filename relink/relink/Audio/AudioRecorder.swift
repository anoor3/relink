import AVFoundation
import Foundation

final class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?

    private let minimumDuration: TimeInterval = 0.15

    @Published var isRecording = false
    @Published var audioURL: URL?

    @Published var errorMessage: String?

    @discardableResult
    func startRecording() -> Bool {
        errorMessage = nil

        let session = AVAudioSession.sharedInstance()

        switch session.recordPermission {
        case .granted:
            break
        case .denied:
            errorMessage = "Microphone permission denied. Enable it in Settings."
            return false
        case .undetermined:
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.errorMessage = granted ? nil : "Microphone permission denied. Enable it in Settings."
                }
            }
            errorMessage = "Allow microphone access, then try again."
            return false
        @unknown default:
            errorMessage = "Microphone permission is unavailable."
            return false
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "Failed to start audio session."
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            audioURL = url
            isRecording = true
            return true
        } catch {
            audioRecorder = nil
            audioURL = nil
            isRecording = false
            errorMessage = "Failed to start recording."
            return false
        }
    }

    func stopRecording() -> URL? {
        let duration = audioRecorder?.currentTime ?? 0
        audioRecorder?.stop()
        isRecording = false

        guard duration >= minimumDuration else {
            if let url = audioURL {
                try? FileManager.default.removeItem(at: url)
            }
            audioRecorder = nil
            audioURL = nil
            errorMessage = "Recording too short — hold for a moment, then release."
            return nil
        }

        return audioURL
    }
}
