import XCTest
@testable import RingVoice

final class VoiceWorkflowTests: XCTestCase {
    // 示例文本
    func testLoadSampleTranscriptEnablesProcessing() {
        var workflow = VoiceWorkflow()

        workflow.loadSampleTranscript()

        XCTAssertTrue(workflow.canProcess)
        XCTAssertEqual(workflow.stage, .draft)
    }

    // 生成卡片
    func testGenerateInsightsCreatesThreeCards() {
        var workflow = VoiceWorkflow()
        workflow.loadSampleTranscript()

        workflow.generateInsights()

        XCTAssertEqual(workflow.stage, .processed)
        XCTAssertEqual(workflow.cards.count, 3)
        XCTAssertEqual(workflow.cards.first?.intent, .reminder)
    }
}

