import XCTest
@testable import RingVoice

final class PhoneSpeechRecorderTests: XCTestCase {
    // 错误文案
    func testRecordingFailedHasReadableDescription() {
        XCTAssertEqual(
            PhoneRecorderError.recordingFailed("无法启动录音").errorDescription,
            "无法启动录音"
        )
    }

    // 权限文案
    func testPermissionDeniedHasReadableDescription() {
        XCTAssertEqual(
            PhoneRecorderError.permissionDenied("麦克风").errorDescription,
            "麦克风权限未开启"
        )
    }
}
