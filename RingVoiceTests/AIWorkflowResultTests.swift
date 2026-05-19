import XCTest
@testable import RingVoice

final class AIWorkflowResultTests: XCTestCase {
    // JSON 解析
    func testDecodeAIWorkflowResult() throws {
        let json = """
        {
          "polishedText": "明天下午三点提醒我给客户发送方案。",
          "summary": "一个定时提醒和一个待办。",
          "cards": [
            {
              "intent": "reminder",
              "title": "发送方案",
              "detail": "提醒用户发送客户方案。",
              "timeText": "明天 15:00"
            },
            {
              "intent": "TODO",
              "title": "检查报价",
              "detail": "发送前确认报价。",
              "timeText": null
            }
          ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let result = try JSONDecoder().decode(AIWorkflowResult.self, from: data)

        XCTAssertEqual(result.cards.count, 2)
        XCTAssertEqual(result.cards.first?.intent, .reminder)
        XCTAssertEqual(result.cards.last?.intent, .todo)
    }

    // 音频编码
    func testStepAudioClientBuildsWAVDataURI() {
        let uri = StepAudioAIClient.wavDataURI(Data([0x52, 0x49]))

        XCTAssertTrue(uri.hasPrefix("data:audio/wav;base64,"))
        XCTAssertTrue(uri.hasSuffix("Ukk="))
    }

    // 直接 JSON
    func testStepAudioClientDecodesRawJSON() throws {
        let result = try StepAudioAIClient.decodeResult(from: """
        {"polishedText":"记录明天开会","summary":"会议提醒","cards":[]}
        """)

        XCTAssertEqual(result.polishedText, "记录明天开会")
        XCTAssertTrue(result.cards.isEmpty)
    }

    // 包裹 JSON
    func testStepAudioClientExtractsWrappedJSON() throws {
        let result = try StepAudioAIClient.decodeResult(from: """
        result:
        {"polishedText":"整理客户材料","summary":"材料整理","cards":[]}
        """)

        XCTAssertEqual(result.summary, "材料整理")
    }

    // 文本返回
    func testStepAudioClientAcceptsPlainTextOutput() throws {
        let output = try StepAudioAIClient.decodeOutput(from: "明天下午提醒我开会。")

        XCTAssertEqual(output.text, "明天下午提醒我开会。")
        XCTAssertNil(output.result)
    }

    // JSON 返回
    func testStepAudioClientAcceptsStructuredOutput() throws {
        let output = try StepAudioAIClient.decodeOutput(from: """
        {"polishedText":"记录想法","summary":"一个想法","cards":[]}
        """)

        XCTAssertEqual(output.text, "记录想法")
        XCTAssertEqual(output.result?.summary, "一个想法")
    }

    // 音频响应
    func testStepAudioClientReadsAudioTranscript() throws {
        let response = """
        {"choices":[{"message":{"content":"","audio":{"transcript":"{\\"polishedText\\":\\"记录想法\\",\\"summary\\":\\"一个想法\\",\\"cards\\":[]}"}}}]}
        """

        let data = try XCTUnwrap(response.data(using: .utf8))
        let content = try StepAudioAIClient.decodeContentEnvelope(from: data)
        let result = try StepAudioAIClient.decodeResult(from: content)

        XCTAssertEqual(result.polishedText, "记录想法")
    }

    // 格式错误
    func testStepAudioClientRejectsInvalidJSON() {
        XCTAssertThrowsError(try StepAudioAIClient.decodeResult(from: "not json")) { error in
            XCTAssertTrue(error is StepAudioAIClientError)
        }
    }
}
