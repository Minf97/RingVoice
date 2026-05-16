enum DemoPhase: String {
    case disconnected = "未连接"
    case connected = "已连接"
    case recording = "录音中"
    case received = "已接收"
    case processing = "处理中"
    case ready = "已完成"
}

enum DemoIntent: String {
    case todo = "TODO"
    case reminder = "定时"
    case material = "素材"
}

struct DemoSession {
    var phase: DemoPhase = .disconnected
    var battery = 86
    var packetCount = 0
    var didVibrate = false
    var intent: DemoIntent = .reminder
    var resultTitle = "给客户发送方案"
    var polishedText = ""
    var reminderText = "未创建"
    var events = ["等待连接蓝牙戒指"]

    var connectionText: String {
        phase == .disconnected ? "断开" : "T3 Ring"
    }

    var canConnect: Bool { phase == .disconnected }
    var canStartRecording: Bool { phase == .connected }
    var canReceiveAudio: Bool { phase == .recording }
    var canFinishRecording: Bool { phase == .recording || phase == .received }
    var canProcessAI: Bool { phase == .received }

    // 状态连接
    mutating func connect() {
        phase = .connected
        events.append("扫描 0xFFF0 并连接成功")
        events.append("订阅 RX 0xFFF7")
        events.append("写入 TX 0x4A 01 00 关闭压缩")
        events.append("写入 TX 0x1C CC=4 切录音模式")
    }

    // 开始录音
    mutating func startRecording() {
        phase = .recording
        packetCount = 0
        didVibrate = false
        events.append("收到 0xC9 AA=3 开始录音")
    }

    // 接收音频
    mutating func receiveAudioPackets() {
        packetCount += 18
        phase = .received
        events.append("接收 PCM 音频包 18 个")
        events.append("组装 16kHz 单声道 WAV")
    }

    // 结束录音
    mutating func finishRecording() {
        phase = .received
        didVibrate = true
        events.append("收到 0xC9 AA=4 音频结束")
        events.append("写入 TX 0xC9 00 关闭发送")
        events.append("写入 TX 0x08 02 震动 200ms")
    }

    // AI 分类
    mutating func processAI() {
        phase = .processing
        events.append("上传 WAV 做语音转文字")
        polishedText = "明天下午三点提醒我给客户发送方案。"
        intent = .reminder
        reminderText = "明天 15:00"
        phase = .ready
        events.append("AI 返回 reminder 意图")
        events.append("准备请求系统通知权限")
    }

    // 重置演示
    mutating func reset() {
        self = DemoSession()
    }
}
