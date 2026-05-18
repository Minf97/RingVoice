import XCTest
@testable import RingVoice

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
        XCTAssertTrue(session.events.contains("订阅音频通道成功：RX 0xFFF7"))
    }

    // 配对日志
    func testConnectWritesPairingSuccessLogs() {
        var session = DemoSession()

        session.connect()

        XCTAssertTrue(session.events.contains("搜索蓝牙设备成功：发现 T3 Ring"))
        XCTAssertTrue(session.events.contains("发送配对指令成功：TX 0x01 PAIR_REQ"))
        XCTAssertTrue(session.events.contains("接收配对信息成功：RX 0x81 PAIR_ACK"))
        XCTAssertTrue(session.events.contains("确认配对成功：T3 Ring 已连接"))
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
        XCTAssertTrue(session.events.contains("发送震动指令成功：TX 0x08 02 200ms"))
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
