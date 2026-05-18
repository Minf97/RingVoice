import XCTest
@testable import RingVoice

final class RingBluetoothPhaseTests: XCTestCase {
    // 连接状态
    func testConnectedLikePhases() {
        XCTAssertTrue(RingBluetoothPhase.connected.isConnectedLike)
        XCTAssertTrue(RingBluetoothPhase.recording.isConnectedLike)
        XCTAssertTrue(RingBluetoothPhase.receiving.isConnectedLike)
        XCTAssertTrue(RingBluetoothPhase.ready.isConnectedLike)
    }

    // 非连接态
    func testDisconnectedLikePhases() {
        XCTAssertFalse(RingBluetoothPhase.disconnected.isConnectedLike)
        XCTAssertFalse(RingBluetoothPhase.scanning.isConnectedLike)
        XCTAssertFalse(RingBluetoothPhase.connecting.isConnectedLike)
        XCTAssertFalse(RingBluetoothPhase.discovering.isConnectedLike)
        XCTAssertFalse(RingBluetoothPhase.failed.isConnectedLike)
    }

    // 连接中状态
    func testConnectingLikePhases() {
        XCTAssertTrue(RingBluetoothPhase.connecting.isConnectingLike)
        XCTAssertTrue(RingBluetoothPhase.discovering.isConnectingLike)
        XCTAssertFalse(RingBluetoothPhase.connected.isConnectingLike)
        XCTAssertFalse(RingBluetoothPhase.disconnected.isConnectingLike)
    }
}
