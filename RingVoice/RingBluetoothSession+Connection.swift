@preconcurrency import CoreBluetooth
import Foundation

extension RingBluetoothSession {
    // 蓝牙检查
    func ensureBluetoothPoweredOn(_ centralManager: CBCentralManager) -> Bool {
        switch centralManager.state {
        case .poweredOn:
            return true
        case .unauthorized:
            markFailed("蓝牙未授权，请在系统设置开启蓝牙权限")
        case .poweredOff:
            markFailed("蓝牙未开启：poweredOff")
        case .unsupported:
            markFailed("当前设备不支持蓝牙")
        case .resetting, .unknown:
            markFailed("蓝牙暂不可用：\(centralManager.state.ringText)")
        @unknown default:
            markFailed("蓝牙状态未知")
        }
        return false
    }

    // 已连提示
    func warnIfAlreadyConnected() -> Bool {
        guard phase.isConnectedLike || txCharacteristic != nil else {
            return false
        }

        events.append("戒指已连接：\(connectionText)")
        return true
    }

    // 开始扫描
    func beginScan(mode: RingScanMode, central: CBCentralManager) {
        central.stopScan()
        discoveredPeripherals = [:]
        scannedDevices = []
        scanMode = mode
        phase = .scanning
    }

    // 系统已连
    @discardableResult
    func refreshSystemConnectedRing(from central: CBCentralManager) -> CBPeripheral? {
        let peripherals = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID])
        guard let firstPeripheral = peripherals.first else {
            clearSystemConnectedNotice()
            return nil
        }

        for peripheral in peripherals {
            upsertScannedDevice(
                peripheral: peripheral,
                serviceText: "\(Self.serviceUUID.uuidString) (system)",
                rssi: 0
            )
        }

        let name = firstPeripheral.name ?? "T3 Ring"
        let notice = "戒指已连接：\(name)"
        connectionText = name
        if connectedRingNotice != notice {
            connectedRingNotice = notice
            events.append(notice)
        }

        return firstPeripheral
    }

    // 清除提示
    func clearSystemConnectedNotice() {
        connectedRingNotice = nil
        if phase.isConnectedLike == false && txCharacteristic == nil {
            connectionText = "断开"
        }
    }

    // 运行态清理
    func resetConnectionRuntime() {
        txCharacteristic = nil
        pendingCommands = []
        activeCommand = nil
        audioQueue = RingAudioBufferQueue()
        audioFlushWorkItem?.cancel()
        audioFlushWorkItem = nil
        packetCount = 0
        didVibrate = false
        audioTranscript = ""
        audioResult = nil
    }
}

extension RingBluetoothPhase {
    // 连接态判断
    var isConnectedLike: Bool {
        switch self {
        case .connected, .recording, .receiving, .ready:
            true
        case .disconnected, .scanning, .connecting, .discovering, .failed:
            false
        }
    }

    // 连接中判断
    var isConnectingLike: Bool {
        switch self {
        case .connecting, .discovering:
            true
        case .disconnected, .scanning, .connected, .recording, .receiving, .ready, .failed:
            false
        }
    }
}
