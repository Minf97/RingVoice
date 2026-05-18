import Foundation

enum StepAudioAIClientError: LocalizedError {
    case missingEnvironment(String)
    case invalidURL
    case invalidStatus(Int, String)
    case emptyContent
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .missingEnvironment(let name):
            "缺少环境变量：\(name)"
        case .invalidURL:
            "AI 接口地址无效"
        case .invalidStatus(let code, let body):
            "音频 AI 请求失败：HTTP \(code)，\(body)"
        case .emptyContent:
            "音频 AI 返回内容为空"
        case .invalidJSON(let content):
            "音频 AI 返回不是目标 JSON：\(content)"
        }
    }
}

struct StepAudioAIClient {
    let apiKey: String
    let baseURL: String
    let model: String

    // 环境读取
    static func fromEnvironment() throws -> StepAudioAIClient {
        let env = ProcessInfo.processInfo.environment

        guard let apiKey = env["STEP_API_KEY"], apiKey.isEmpty == false else {
            throw StepAudioAIClientError.missingEnvironment("STEP_API_KEY")
        }

        guard let baseURL = env["STEP_API_BASE_URL"], baseURL.isEmpty == false else {
            throw StepAudioAIClientError.missingEnvironment("STEP_API_BASE_URL")
        }

        guard let model = env["STEP_AUDIO_MODEL"], model.isEmpty == false else {
            throw StepAudioAIClientError.missingEnvironment("STEP_AUDIO_MODEL")
        }

        return StepAudioAIClient(apiKey: apiKey, baseURL: baseURL, model: model)
    }

    // 音频整理
    func generateInsights(fromWAVData wavData: Data) async throws -> AIWorkflowResult {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw StepAudioAIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            StepAudioChatRequest(
                model: model,
                modalities: ["text", "audio"],
                messages: [
                    .system(Self.systemPrompt),
                    .userAudio(text: Self.userPrompt, wavData: wavData)
                ],
                stream: false
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StepAudioAIClientError.invalidStatus(statusCode, body)
        }

        let content = try Self.decodeContentEnvelope(from: data)
        return try Self.decodeResult(from: content)
    }

    // 响应拆包
    static func decodeContentEnvelope(from data: Data) throws -> String {
        do {
            return try JSONDecoder().decode(StepAudioChatResponse.self, from: data).content()
        } catch let error as StepAudioAIClientError {
            throw error
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StepAudioAIClientError.invalidJSON(shorten(body))
        }
    }

    // JSON 解析
    static func decodeResult(from content: String) throws -> AIWorkflowResult {
        let json = try extractJSONObject(from: content)
        guard let data = json.data(using: .utf8) else {
            throw StepAudioAIClientError.emptyContent
        }

        do {
            return try JSONDecoder().decode(AIWorkflowResult.self, from: data)
        } catch {
            throw StepAudioAIClientError.invalidJSON(shorten(content))
        }
    }

    // 音频地址
    static func wavDataURI(_ data: Data) -> String {
        "data:audio/wav;base64,\(data.base64EncodedString())"
    }

    // JSON 提取
    private static func extractJSONObject(from content: String) throws -> String {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            throw StepAudioAIClientError.emptyContent
        }

        if text.hasPrefix("{"), text.hasSuffix("}") {
            return text
        }

        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw StepAudioAIClientError.invalidJSON(shorten(text))
        }

        return String(text[start...end])
    }

    // 内容截断
    private static func shorten(_ content: String) -> String {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count <= 240 {
            return text
        }
        return "\(text.prefix(240))..."
    }

    // 系统提示
    private static let systemPrompt = """
    You are an audio understanding engine for an IoT voice assistant.
    Listen to the audio directly and return one valid JSON object only.
    Do not use Markdown, code fences, comments, or extra prose.
    """

    // 用户提示
    private static let userPrompt = """
    Understand the attached voice audio and convert it into JSON:
    {
      "polishedText": "A polished Chinese version of the user's spoken content",
      "summary": "A one-sentence Chinese summary",
      "cards": [
        {
          "intent": "TODO|reminder|material",
          "title": "A short Chinese card title",
          "detail": "Concrete Chinese execution details",
          "timeText": "Natural language time if this is a reminder, otherwise null"
        }
      ]
    }
    Use exactly these keys: polishedText, summary, cards, intent, title, detail, timeText.
    If the audio is unclear, return empty strings and an empty cards array.
    """
}

private struct StepAudioChatRequest: Encodable {
    let model: String
    let modalities: [String]
    let audio = StepAudioOutput()
    let messages: [StepAudioMessage]
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case modalities
        case audio
        case messages
        case stream
    }
}

private struct StepAudioOutput: Encodable {
    let voice = "wenrounansheng"
    let format = "wav"
}

private struct StepAudioMessage: Encodable {
    let role: String
    let content: StepAudioContent

    static func system(_ content: String) -> StepAudioMessage {
        StepAudioMessage(role: "system", content: .text(content))
    }

    static func userAudio(text: String, wavData: Data) -> StepAudioMessage {
        StepAudioMessage(
            role: "user",
            content: .parts([
                .text(text),
                .inputAudio(StepAudioInputAudio(data: StepAudioAIClient.wavDataURI(wavData)))
            ])
        )
    }
}

private enum StepAudioContent: Encodable {
    case text(String)
    case parts([StepAudioContentPart])

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }
}

private enum StepAudioContentPart: Encodable {
    case text(String)
    case inputAudio(StepAudioInputAudio)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case inputAudio = "input_audio"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .inputAudio(let audio):
            try container.encode("input_audio", forKey: .type)
            try container.encode(audio, forKey: .inputAudio)
        }
    }
}

private struct StepAudioInputAudio: Encodable {
    let data: String
    let format = "wav"
}

private struct StepAudioChatResponse: Decodable {
    let choices: [Choice]

    // 内容提取
    func content() throws -> String {
        guard let message = choices.first?.message else {
            throw StepAudioAIClientError.emptyContent
        }

        if let content = message.content, content.isEmpty == false {
            return content
        }

        if let transcript = message.audio?.transcript, transcript.isEmpty == false {
            return transcript
        }

        throw StepAudioAIClientError.emptyContent
    }

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
        let audio: Audio?
    }

    struct Audio: Decodable {
        let transcript: String?
    }
}
