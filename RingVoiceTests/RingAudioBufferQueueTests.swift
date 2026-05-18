import XCTest
@testable import RingVoice

final class RingAudioBufferQueueTests: XCTestCase {
    // 批量摘要
    func testDrainPendingBatchSummarizesQueuedPackets() {
        var queue = RingAudioBufferQueue()

        queue.append(Data([0xCA, 0x00, 0x01, 0x10]))
        queue.append(Data([0xCA, 0x00, 0x02, 0x11]))

        let batch = queue.drainPendingBatch()

        XCTAssertEqual(batch?.packetCount, 2)
        XCTAssertEqual(batch?.byteCount, 8)
        XCTAssertEqual(batch?.firstPacketID, UInt16(1))
        XCTAssertEqual(batch?.lastPacketID, UInt16(2))
        XCTAssertEqual(batch?.pcmData, Data([0x10, 0x11]))
        XCTAssertEqual(queue.packetCount, 2)
        XCTAssertNil(queue.drainPendingBatch())
    }

    // WAV 编码
    func testWAVEncoderBuildsExpectedHeader() throws {
        let wav = try RingWAVEncoder.encode(pcmData: Data([0x10, 0x11]))

        XCTAssertEqual(String(data: wav.subdata(in: 0..<4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: wav.subdata(in: 8..<12), encoding: .ascii), "WAVE")
        XCTAssertEqual(wav.count, 46)
        XCTAssertEqual(Data(wav.suffix(2)), Data([0x10, 0x11]))
    }

    // 空音频
    func testWAVEncoderRejectsEmptyPCM() {
        XCTAssertThrowsError(try RingWAVEncoder.encode(pcmData: Data()))
    }

    // 序号提示
    func testQueueTracksDroppedPackets() {
        var queue = RingAudioBufferQueue()

        queue.append(Data([0xCA, 0x00, 0x01, 0x10]))
        queue.append(Data([0xCA, 0x00, 0x03, 0x11]))

        let batch = queue.drainPendingBatch()

        XCTAssertEqual(batch?.droppedPacketCount, 1)
        XCTAssertTrue(batch?.logText(totalPacketCount: queue.packetCount).contains("序号断点") == false)
    }
}
