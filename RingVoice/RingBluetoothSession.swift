@preconcurrency import CoreBluetooth
import Foundation

enum RingBluetoothPhase: String {
    case disconnected = "未连接"
    case scanning = "扫描中"
    case connecting = "连接中"
    case discovering = "发现服务"
    case connected = "已连接"
    case recording = "录音中"
    case receiving = "接收中"
    case ready = "已完成"
    case failed = "失败"
}

@MainActor
final class RingBluetoothSession: NSObject, ObservableObject {
    @Published var phase: RingBluetoothPhase = .disconnected
    @Published var connectionText = "断开"
    @Published var packetCount = 0
    @Published var didVibrate = false
    @Published var audioTranscript = ""
    @Published var audioResult: AIWorkflowResult?
    @Published var events = ["等待真实蓝牙连接"]
    @Published var scannedDevices: [RingScannedDevice] = []
    @Published var connectedRingNotice: String?

    static let serviceUUID = CBUUID(string: "FFF0")
    static let txUUID = CBUUID(string: "FFF6")
    static let rxUUID = CBUUID(string: "FFF7")

    var centralManager: CBCentralManager?
    var peripheral: CBPeripheral?
    var txCharacteristic: CBCharacteristic?
    var pendingCommands: [RingBluetoothCommand] = []
    var activeCommand: RingBluetoothCommand?
    var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    var scanMode: RingScanMode = .browsing
    var audioQueue = RingAudioBufferQueue()
    var audioFlushWorkItem: DispatchWorkItem?

    var canConnect: Bool {
        phase == .disconnected || phase == .failed || phase == .connected || phase == .ready
    }

    var canScan: Bool {
        phase == .disconnected || phase == .failed || phase == .scanning
            || phase == .connected || phase == .ready
    }

    var canStartRecording: Bool {
        phase == .connected || phase == .ready
    }

    var canReceiveAudio: Bool {
        phase == .recording || phase == .receiving
    }

    var canFinishRecording: Bool {
        phase == .recording || phase == .receiving
    }

    var canProcessAI: Bool {
        packetCount > 0 && phase != .recording && phase != .receiving
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // 扫描列表
    func scanDevices() {
        guard let centralManager else {
            markFailed("蓝牙管理器未初始化")
            return
        }

        if phase == .scanning {
            stopScan()
            return
        }

        guard warnIfAlreadyConnected() == false else { return }
        guard ensureBluetoothPoweredOn(centralManager) else { return }

        if refreshSystemConnectedRing(from: centralManager) != nil {
            return
        }

        beginScan(mode: .browsing, central: centralManager)
        events.append("开始扫描有效设备：名称含 T3 或 Service FFF0")
        centralManager.scanForPeripherals(withServices: nil)
    }

    // 停止扫描
    func stopScan() {
        centralManager?.stopScan()
        if phase == .scanning {
            phase = .disconnected
        }
        events.append("停止扫描，共发现 \(scannedDevices.count) 个设备")
    }

    // 连接设备
    func connectDevice(id: UUID) {
        guard let centralManager else {
            markFailed("蓝牙管理器未初始化")
            return
        }

        guard warnIfAlreadyConnected() == false else { return }
        guard ensureBluetoothPoweredOn(centralManager) else { return }

        guard let target = discoveredPeripherals[id] else {
            markFailed("设备不存在或已过期")
            return
        }

        centralManager.stopScan()
        connectPeripheral(target, central: centralManager)
    }

    // 连接戒指
    func connect() {
        guard let centralManager else {
            markFailed("蓝牙管理器未初始化")
            return
        }

        guard warnIfAlreadyConnected() == false else { return }
        guard ensureBluetoothPoweredOn(centralManager) else { return }

        if let connected = refreshSystemConnectedRing(from: centralManager) {
            events.append("戒指已连接，正在接入 App")
            connectPeripheral(connected, central: centralManager)
            return
        }

        beginScan(mode: .connectingRing, central: centralManager)
        events.append("开始扫描真实戒指：名称含 T3 或 Service FFF0")
        centralManager.scanForPeripherals(withServices: nil)
    }

    // 重置连接
    func reset() {
        if let peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }

        peripheral = nil
        txCharacteristic = nil
        pendingCommands = []
        activeCommand = nil
        discoveredPeripherals = [:]
        scannedDevices = []
        connectedRingNotice = nil
        scanMode = .browsing
        audioQueue = RingAudioBufferQueue()
        audioFlushWorkItem?.cancel()
        audioFlushWorkItem = nil
        packetCount = 0
        didVibrate = false
        audioTranscript = ""
        audioResult = nil
        phase = .disconnected
        connectionText = "断开"
        events = ["等待真实蓝牙连接"]
    }

    func upsertScannedDevice(
        peripheral: CBPeripheral,
        serviceText: String,
        rssi: NSNumber
    ) {
        let name = peripheral.name ?? "未命名设备"
        let isCandidate = name.localizedCaseInsensitiveContains("T3")
            || serviceText.localizedCaseInsensitiveContains(Self.serviceUUID.uuidString)
        guard isCandidate else { return }

        discoveredPeripherals[peripheral.identifier] = peripheral
        let item = RingScannedDevice(
            id: peripheral.identifier,
            name: name,
            rssi: rssi.intValue,
            serviceText: serviceText,
            isRingCandidate: isCandidate
        )

        if let index = scannedDevices.firstIndex(where: { $0.id == item.id }) {
            scannedDevices[index] = item
        } else {
            scannedDevices.append(item)
        }

        scannedDevices.sort { $0.rssi > $1.rssi }
    }

    func connectPeripheral(_ peripheral: CBPeripheral, central: CBCentralManager) {
        resetConnectionRuntime()
        scanMode = .browsing
        self.peripheral = peripheral
        peripheral.delegate = self
        phase = .connecting
        connectionText = peripheral.name ?? peripheral.identifier.uuidString
        events.append("准备连接设备：\(connectionText)")
        central.connect(peripheral)
    }

    func enqueue(_ commands: [RingBluetoothCommand]) {
        guard txCharacteristic != nil, peripheral != nil else {
            markFailed("TX FFF6 未就绪")
            return
        }

        pendingCommands.append(contentsOf: commands)
        sendNextCommand()
    }

    func sendSetupCommands() {
        enqueue([
            RingBluetoothCommands.setUncompressedAudio,
            RingBluetoothCommands.setRecordingMode
        ])
    }

    func sendNextCommand() {
        guard activeCommand == nil else { return }
        guard pendingCommands.isEmpty == false else { return }
        guard let peripheral, let txCharacteristic else {
            markFailed("写入通道丢失")
            return
        }

        let command = pendingCommands.removeFirst()
        activeCommand = command
        events.append("发送指令：\(command.title) \(command.bytes.ringHexText)")
        peripheral.writeValue(command.bytes, for: txCharacteristic, type: .withResponse)
    }

    func handleCommandWritten(_ command: RingBluetoothCommand) {
        switch command.kind {
        case .setup:
            if pendingCommands.isEmpty {
                phase = .connected
                events.append("真实戒指初始化完成")
            }
        case .startAudio:
            phase = .recording
            events.append("录音发送已打开，等待 RX 事件")
        case .stopAudio:
            phase = .ready
            events.append("录音发送已关闭")
        case .vibrate:
            didVibrate = true
            events.append("震动指令已确认")
        }
    }

    func markFailed(_ message: String) {
        phase = .failed
        events.append("失败：\(message)")
    }
}
