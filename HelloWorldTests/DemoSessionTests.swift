import XCTest
@testable import HelloWorld

// API 索引:
// XCTestCase 定义测试类。Docs: https://developer.apple.com/documentation/xctest/xctestcase
// XCTAssertEqual 校验相等。Docs: https://developer.apple.com/documentation/xctest/1500970-xctassertequal
// XCTAssertTrue 校验真值。Docs: https://developer.apple.com/documentation/xctest/xctasserttrue

final class DemoSessionTests: XCTestCase {
    // 连接状态
    func testConnectMovesToConnected() {
        var session = DemoSession()

        session.connect()

        XCTAssertEqual(session.phase, .connected)
        XCTAssertEqual(session.connectionText, "T3 Ring")
        XCTAssertTrue(session.events.contains("订阅 RX 0xFFF7"))
    }

    // 录音状态
    func testRecordingFlowReceivesAudio() {
        var session = DemoSession()
        session.connect()

        session.startRecording()
        session.receiveAudioPackets()

        XCTAssertEqual(session.phase, .received)
        XCTAssertEqual(session.packetCount, 18)
        XCTAssertTrue(session.canProcessAI)
    }

    // 结束震动
    func testFinishRecordingTriggersVibration() {
        var session = DemoSession()
        session.connect()
        session.startRecording()

        session.finishRecording()

        XCTAssertEqual(session.phase, .received)
        XCTAssertTrue(session.didVibrate)
        XCTAssertTrue(session.events.contains("写入 TX 0x08 02 震动 200ms"))
    }

    // AI 结果
    func testProcessAIGeneratesReminder() {
        var session = DemoSession()
        session.connect()
        session.startRecording()
        session.receiveAudioPackets()

        session.processAI()

        XCTAssertEqual(session.phase, .ready)
        XCTAssertEqual(session.intent, .reminder)
        XCTAssertEqual(session.reminderText, "明天 15:00")
    }
}

