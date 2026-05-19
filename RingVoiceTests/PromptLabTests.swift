import XCTest
@testable import RingVoice

final class PromptLabTests: XCTestCase {
    // 英文提示
    func testDefaultPromptIsEnglish() {
        XCTAssertTrue(PromptLabDefaults.systemPrompt.contains("IoT voice ring"))
        XCTAssertFalse(PromptLabDefaults.systemPrompt.contains("你是"))
    }

    // 消息角色
    func testPromptLabMessageTitle() {
        XCTAssertEqual(PromptLabMessage(role: "user", content: "Hi").title, "User")
        XCTAssertEqual(PromptLabMessage(role: "assistant", content: "Hello").title, "Assistant")
    }

    // 空响应诊断
    func testStepClientReportsEmptyContentDetails() throws {
        let response = """
        {"choices":[{"message":{"role":"assistant","content":"","reasoning":"thinking"},"finish_reason":"stop"}]}
        """

        let data = try XCTUnwrap(response.data(using: .utf8))
        XCTAssertThrowsError(try StepAIClient.decodeContentEnvelope(from: data)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "AI 返回内容为空：finish_reason=stop，reasoning_length=8"
            )
        }
    }
}
