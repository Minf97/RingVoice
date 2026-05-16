import AVFoundation
import Speech

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
    case speechUnavailable
    case permissionDenied(String)
    case alreadyRecording
    case notRecording
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .speechUnavailable:
            "当前设备不可用语音识别"
        case .permissionDenied(let name):
            "\(name)权限未开启"
        case .alreadyRecording:
            "录音已经开始"
        case .notRecording:
            "当前没有录音"
        case .emptyTranscript:
            "没有识别到语音内容"
        }
    }
}

@MainActor
final class PhoneSpeechRecorder: NSObject, ObservableObject {
    @Published private(set) var phase: PhoneRecordingPhase = .idle
    @Published private(set) var transcript = ""

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // 开始录音
    func start() async throws {
        guard phase.isRecording == false else {
            throw PhoneRecorderError.alreadyRecording
        }

        try await authorize()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw PhoneRecorderError.speechUnavailable
        }

        transcript = ""
        phase = .recording
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        try configureAudioSession()
        installAudioTap(request: request)
        startRecognition(speechRecognizer: speechRecognizer, request: request)

        audioEngine.prepare()
        try audioEngine.start()
    }

    // 结束录音
    func stop() throws -> String {
        guard audioEngine.isRunning else {
            throw PhoneRecorderError.notRecording
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        try AVAudioSession.sharedInstance().setActive(false)

        recognitionRequest = nil
        recognitionTask = nil

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            phase = .idle
            throw PhoneRecorderError.emptyTranscript
        }

        phase = .finished
        return text
    }

    // 请求权限
    private func authorize() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw PhoneRecorderError.permissionDenied("语音识别")
        }

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
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true)
    }

    // 安装采集
    private func installAudioTap(request: SFSpeechAudioBufferRecognitionRequest) {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    // 实时转写
    private func startRecognition(
        speechRecognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result {
                    self?.transcript = result.bestTranscription.formattedString
                }

                if let error, self?.phase == .recording {
                    self?.phase = .failed(error.localizedDescription)
                }
            }
        }
    }
}
