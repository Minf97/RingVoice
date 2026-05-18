@preconcurrency import CoreBluetooth
import Foundation

extension RingBluetoothSession: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            events.append("蓝牙状态：\(central.state.ringText)")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let serviceText = advertisementServiceText(advertisementData)
        Task { @MainActor in
            upsertScannedDevice(
                peripheral: peripheral,
                serviceText: serviceText,
                rssi: RSSI
            )
            guard discoveredPeripherals[peripheral.identifier] != nil else { return }
            events.append("扫描到有效设备：\(peripheral.name ?? "未命名设备")，RSSI \(RSSI)")

            if scanMode == .connectingRing {
                central.stopScan()
                connectPeripheral(peripheral, central: central)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            phase = .discovering
            connectionText = peripheral.name ?? peripheral.identifier.uuidString
            events.append("连接成功：\(connectionText)")
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            markFailed("连接失败：\(error?.localizedDescription ?? "未知错误")")
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            phase = .disconnected
            connectionText = "断开"
            events.append("连接断开：\(error?.localizedDescription ?? "用户或设备断开")")
        }
    }
}

private func advertisementServiceText(_ advertisementData: [String: Any]) -> String {
    let keys = [
        CBAdvertisementDataServiceUUIDsKey,
        CBAdvertisementDataOverflowServiceUUIDsKey
    ]
    let values = keys
        .compactMap { advertisementData[$0] as? [CBUUID] }
        .flatMap { $0 }
        .map(\.uuidString)

    return values.isEmpty ? "--" : values.joined(separator: ", ")
}

extension RingBluetoothSession: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                markFailed("发现服务失败：\(error.localizedDescription)")
                return
            }

            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
                markFailed("未找到服务 FFF0")
                return
            }

            events.append("发现服务成功：FFF0")
            peripheral.discoverCharacteristics([Self.txUUID, Self.rxUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                markFailed("发现特征失败：\(error.localizedDescription)")
                return
            }

            guard let characteristics = service.characteristics else {
                markFailed("服务没有特征：FFF0")
                return
            }

            guard let tx = characteristics.first(where: { $0.uuid == Self.txUUID }) else {
                markFailed("未找到 TX FFF6")
                return
            }

            guard let rx = characteristics.first(where: { $0.uuid == Self.rxUUID }) else {
                markFailed("未找到 RX FFF7")
                return
            }

            txCharacteristic = tx
            events.append("发现 TX 成功：FFF6")
            events.append("发现 RX 成功：FFF7")
            peripheral.setNotifyValue(true, for: rx)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                markFailed("订阅 RX 失败：\(error.localizedDescription)")
                return
            }

            guard characteristic.uuid == Self.rxUUID, characteristic.isNotifying else {
                markFailed("RX FFF7 未进入通知状态")
                return
            }

            events.append("订阅 RX 成功：FFF7")
            sendSetupCommands()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                activeCommand = nil
                markFailed("写入失败：\(error.localizedDescription)")
                return
            }

            guard let command = activeCommand else {
                markFailed("写入回调缺少当前命令")
                return
            }

            events.append("写入成功：\(command.title)")
            activeCommand = nil
            handleCommandWritten(command)
            sendNextCommand()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                markFailed("接收 RX 失败：\(error.localizedDescription)")
                return
            }

            guard let data = characteristic.value else {
                markFailed("RX 数据为空")
                return
            }

            handleReceived(data)
        }
    }
}

extension CBManagerState {
    // 状态文字
    var ringText: String {
        switch self {
        case .unknown:
            "unknown"
        case .resetting:
            "resetting"
        case .unsupported:
            "unsupported"
        case .unauthorized:
            "unauthorized"
        case .poweredOff:
            "poweredOff"
        case .poweredOn:
            "poweredOn"
        @unknown default:
            "unknown"
        }
    }
}
