import Foundation

enum RingCommandKind {
    case setup
    case startAudio
    case stopAudio
    case vibrate
}

struct RingBluetoothCommand {
    let title: String
    let bytes: Data
    let kind: RingCommandKind
}

enum RingBluetoothCommands {
    // 打包命令
    static func packet(command: UInt8, payload: [UInt8]) -> Data {
        var bytes = [command] + payload
        while bytes.count < 15 {
            bytes.append(0)
        }

        let checksum = bytes.reduce(UInt8(0)) { partial, item in
            partial &+ item
        }
        bytes.append(checksum)
        return Data(bytes)
    }

    // 关闭压缩
    static var setUncompressedAudio: RingBluetoothCommand {
        RingBluetoothCommand(
            title: "设置不压缩音频 0x4A",
            bytes: packet(command: 0x4A, payload: [0x01, 0x00]),
            kind: .setup
        )
    }

    // 录音模式
    static var setRecordingMode: RingBluetoothCommand {
        RingBluetoothCommand(
            title: "切换 HID 录音模式 0x1C",
            bytes: packet(command: 0x1C, payload: [0x00, 0x00, 0x04]),
            kind: .setup
        )
    }

    // 打开音频
    static var startAudio: RingBluetoothCommand {
        RingBluetoothCommand(
            title: "打开录音发送 0xC9",
            bytes: packet(command: 0xC9, payload: [0x01]),
            kind: .startAudio
        )
    }

    // 关闭音频
    static var stopAudio: RingBluetoothCommand {
        RingBluetoothCommand(
            title: "关闭录音发送 0xC9",
            bytes: packet(command: 0xC9, payload: [0x00]),
            kind: .stopAudio
        )
    }

    // 震动反馈
    static var vibrate200ms: RingBluetoothCommand {
        RingBluetoothCommand(
            title: "震动反馈 200ms 0x08",
            bytes: packet(command: 0x08, payload: [0x02]),
            kind: .vibrate
        )
    }
}

extension Data {
    // 十六进制显示
    var ringHexText: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
