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
}
