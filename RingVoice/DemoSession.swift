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
    var events = ["准备模拟链路"]

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
        events.append("搜索蓝牙设备成功：发现 T3 Ring")
        events.append("发送配对指令成功：TX 0x01 PAIR_REQ")
        events.append("接收配对信息成功：RX 0x81 PAIR_ACK")
        events.append("确认配对成功：T3 Ring 已连接")
        events.append("订阅音频通道成功：RX 0xFFF7")
        events.append("设置传输成功：TX 0x4A 01 00")
        events.append("切换模式成功：TX 0x1C CC=4")
    }

    // 开始录音
    mutating func startRecording() {
        phase = .recording
        packetCount = 0
        didVibrate = false
        events.append("发送录音准备成功：TX 0xC9 01")
        events.append("接收按键信号成功：RX 0xC9 AA=3")
        events.append("确认录音开始成功")
    }

    // 接收音频
    mutating func receiveAudioPackets() {
        packetCount += 18
        phase = .received
        events.append("接收音频包成功：PCM x18")
        events.append("校验音频序号成功：无丢包")
        events.append("组装音频成功：16kHz 单声道 WAV")
    }

    // 结束录音
    mutating func finishRecording() {
        phase = .received
        didVibrate = true
        events.append("接收结束信号成功：RX 0xC9 AA=4")
        events.append("发送停止指令成功：TX 0xC9 00")
        events.append("发送震动指令成功：TX 0x08 02 200ms")
        events.append("确认录音结束成功")
    }

    // AI 分类
    mutating func processAI() {
        phase = .processing
        events.append("发送音频 AI 成功：WAV")
        events.append("音频理解成功")
        polishedText = "明天下午三点提醒我给客户发送方案。"
        intent = .reminder
        reminderText = "明天 15:00"
        phase = .ready
        events.append("AI 分类成功：reminder")
        events.append("提醒解析成功：明天 15:00")
        events.append("链路完成成功")
    }

    // 重置演示
    mutating func reset() {
        self = DemoSession()
    }
}
