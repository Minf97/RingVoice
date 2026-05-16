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
}
