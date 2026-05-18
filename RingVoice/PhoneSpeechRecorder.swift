import AVFoundation
import Foundation

enum PhoneRecordingPhase: Equatable {
    case idle
    case recording
    case finished
    case failed(String)

    var isRecording: Bool {
        self == .recording
    }
}

enum PhoneRecorderError: LocalizedError {
    case permissionDenied(String)
    case alreadyRecording
    case notRecording
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let name):
            "\(name)权限未开启"
        case .alreadyRecording:
            "录音已经开始"
        case .notRecording:
            "当前没有录音"
        case .recordingFailed(let message):
            message
        }
    }
}

@MainActor
final class PhoneSpeechRecorder: NSObject, ObservableObject {
    @Published private(set) var phase: PhoneRecordingPhase = .idle

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    // 开始录音
    func start() async throws {
        guard phase.isRecording == false else {
            throw PhoneRecorderError.alreadyRecording
        }

        try await authorizeMicrophone()

        do {
            try configureAudioSession()
            try prepareRecorder()
            phase = .recording
        } catch {
            cleanupRecording()
            phase = .failed(error.localizedDescription)
            throw error
        }
    }

    // 结束录音
    func stop() async throws -> Data {
        guard let audioRecorder else {
            throw PhoneRecorderError.notRecording
        }

        audioRecorder.stop()
        let url = recordingURL
        audioRecorderDelete()
        phase = .idle
        try AVAudioSession.sharedInstance().setActive(false)

        guard let url else {
            throw PhoneRecorderError.recordingFailed("录音文件缺失")
        }

        let audioData = try Data(contentsOf: url)
        phase = .finished
        return audioData
    }

    // 请求权限
    private func authorizeMicrophone() async throws {
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }

        guard microphoneGranted else {
            throw PhoneRecorderError.permissionDenied("麦克风")
        }
    }

    // 音频会话
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default, options: [.duckOthers])
        try audioSession.setActive(true)
    }

    // 准备录音
    private func prepareRecorder() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ringvoice-phone-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = false
        guard recorder.record() else {
            try AVAudioSession.sharedInstance().setActive(false)
            throw PhoneRecorderError.recordingFailed("无法启动录音")
        }

        audioRecorder = recorder
        recordingURL = url
    }

    // 清理资源
    private func cleanupRecording(keepFileURL: Bool) {
        audioRecorder?.stop()
        audioRecorder = nil
        if keepFileURL == false {
            recordingURL = nil
        }
    }

    // 清理资源
    private func cleanupRecording() {
        cleanupRecording(keepFileURL: false)
    }

    // 清空引用
    private func audioRecorderDelete() {
        audioRecorder = nil
        recordingURL = nil
    }
}
