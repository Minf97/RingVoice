import Foundation

// API 索引:
// URLSession 发送网络请求。Docs: https://developer.apple.com/documentation/foundation/urlsession
// URLRequest 配置请求信息。Docs: https://developer.apple.com/documentation/foundation/urlrequest
// JSONEncoder 编码请求体。Docs: https://developer.apple.com/documentation/foundation/jsonencoder
// JSONDecoder 解码响应体。Docs: https://developer.apple.com/documentation/foundation/jsondecoder
// ProcessInfo 读取环境变量。Docs: https://developer.apple.com/documentation/foundation/processinfo

enum StepAIClientError: LocalizedError {
    case missingEnvironment(String)
    case invalidURL
    case invalidStatus(Int, String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .missingEnvironment(let name):
            "缺少环境变量：\(name)"
        case .invalidURL:
            "AI 接口地址无效"
        case .invalidStatus(let code, let body):
            "AI 请求失败：HTTP \(code)，\(body)"
        case .emptyContent:
            "AI 返回内容为空"
        }
    }
}

struct StepAIClient {
    let apiKey: String
    let baseURL: String
    let model: String

    // 环境读取
    static func fromEnvironment() throws -> StepAIClient {
        let env = ProcessInfo.processInfo.environment

        guard let apiKey = env["STEP_API_KEY"], apiKey.isEmpty == false else {
            throw StepAIClientError.missingEnvironment("STEP_API_KEY")
        }

        guard let baseURL = env["STEP_API_BASE_URL"], baseURL.isEmpty == false else {
            throw StepAIClientError.missingEnvironment("STEP_API_BASE_URL")
        }

        guard let model = env["STEP_AI_MODEL"], model.isEmpty == false else {
            throw StepAIClientError.missingEnvironment("STEP_AI_MODEL")
        }

        return StepAIClient(apiKey: apiKey, baseURL: baseURL, model: model)
    }

    // 生成卡片
    func generateInsights(from transcript: String) async throws -> AIWorkflowResult {
        let response = try await sendChat(
            messages: [
                .init(role: "system", content: Self.systemPrompt),
                .init(role: "user", content: Self.prompt(transcript: transcript))
            ],
            maxTokens: 800
        )
        let content = try response.content()

        guard let data = content.data(using: .utf8) else {
            throw StepAIClientError.emptyContent
        }

        return try JSONDecoder().decode(AIWorkflowResult.self, from: data)
    }

    // 提示测试
    func chat(systemPrompt: String, userMessage: String) async throws -> String {
        try await chat(
            systemPrompt: systemPrompt,
            messages: [.init(role: "user", content: userMessage)]
        )
    }

    // 多轮聊天
    func chat(systemPrompt: String, messages: [AIChatMessage]) async throws -> String {
        let response = try await sendChat(
            messages: [.init(role: "system", content: systemPrompt)] + messages.map(\.stepMessage),
            maxTokens: 600
        )

        return try response.content()
    }

    // 请求发送
    private func sendChat(messages: [StepMessage], maxTokens: Int) async throws -> StepChatResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw StepAIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            StepChatRequest(
                model: model,
                messages: messages,
                temperature: 0.2,
                maxTokens: maxTokens
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StepAIClientError.invalidStatus(statusCode, body)
        }

        return try JSONDecoder().decode(StepChatResponse.self, from: data)
    }

    // 系统提示
    private static let systemPrompt = """
    You are an information extraction engine for an IoT voice assistant.
    Return valid JSON only. Do not use Markdown, code fences, or extra prose.
    """

    // 用户提示
    private static func prompt(transcript: String) -> String {
        """
        Convert the following Bluetooth ring voice transcript into JSON:
        {
          "polishedText": "A polished version of the full transcript",
          "summary": "A one-sentence summary",
          "cards": [
            {
              "intent": "TODO|reminder|material",
              "title": "A short card title",
              "detail": "Concrete execution details",
              "timeText": "Natural language time if this is a reminder, otherwise null"
            }
          ]
        }
        Transcript: \(transcript)
        """
    }
}

struct AIChatMessage: Equatable {
    let role: String
    let content: String

    // 消息转换
    fileprivate var stepMessage: StepMessage {
        StepMessage(role: role, content: content)
    }
}

private struct StepChatRequest: Encodable {
    let model: String
    let messages: [StepMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

fileprivate struct StepMessage: Codable {
    let role: String
    let content: String
}

private struct StepChatResponse: Decodable {
    let choices: [Choice]

    // 内容提取
    func content() throws -> String {
        guard let content = choices.first?.message.content, content.isEmpty == false else {
            throw StepAIClientError.emptyContent
        }

        return content
    }

    struct Choice: Decodable {
        let message: StepMessage
    }
}
