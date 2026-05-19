import Foundation

struct StepAudioChatRequest: Encodable {
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

struct StepAudioOutput: Encodable {
    let voice = "wenrounansheng"
    let format = "wav"
}

struct StepAudioMessage: Encodable {
    let role: String
    let content: StepAudioContent

    // 系统消息
    static func system(_ content: String) -> StepAudioMessage {
        StepAudioMessage(role: "system", content: .text(content))
    }

    // 音频消息
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

enum StepAudioContent: Encodable {
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

enum StepAudioContentPart: Encodable {
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

struct StepAudioInputAudio: Encodable {
    let data: String
    let format = "wav"
}

struct StepAudioChatResponse: Decodable {
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
