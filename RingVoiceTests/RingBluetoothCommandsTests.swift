import XCTest
@testable import RingVoice

final class RingBluetoothCommandsTests: XCTestCase {
    // CRC 校验
    func testPacketBuildsSixteenBytesWithChecksum() {
        let packet = RingBluetoothCommands.packet(command: 0x4A, payload: [0x01, 0x00])
        let bytes = Array(packet)

        XCTAssertEqual(bytes.count, 16)
        XCTAssertEqual(bytes[0], 0x4A)
        XCTAssertEqual(bytes[1], 0x01)
        XCTAssertEqual(bytes[15], 0x4B)
    }

    // 录音指令
    func testStartAudioCommandUsesC9OpenPayload() {
        let bytes = Array(RingBluetoothCommands.startAudio.bytes)

        XCTAssertEqual(bytes.count, 16)
        XCTAssertEqual(bytes[0], 0xC9)
        XCTAssertEqual(bytes[1], 0x01)
        XCTAssertEqual(bytes[15], 0xCA)
    }
}
