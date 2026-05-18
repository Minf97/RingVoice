import SwiftUI

struct DebugLabView: View {
    @ObservedObject var session: RingBluetoothSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                statusView
                scanView
                actionView
                eventLogView
                resultView
                PromptLabView()
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ring Voice Demo")
                .font(.system(size: 30, weight: .bold))

            Text("连接真实蓝牙戒指，记录扫描、连接、写入和 RX 回调。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设备状态")
                .font(.headline)

            HStack(spacing: 12) {
                statusPill(title: "连接", value: session.connectionText)
                statusPill(title: "阶段", value: session.phase.rawValue)
                statusPill(title: "电量", value: "--")
            }

            HStack(spacing: 12) {
                metricView(title: "音频包", value: "\(session.packetCount)")
                metricView(title: "震动", value: session.didVibrate ? "已触发" : "未触发")
            }

            if let notice = session.connectedRingNotice {
                Text(notice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("真实链路")
                .font(.headline)

            HStack(spacing: 10) {
                actionButton("连接戒指", enabled: session.canConnect) {
                    session.connect()
                }

                actionButton("按下录音", enabled: session.canStartRecording) {
                    session.startRecording()
                }
            }

            HStack(spacing: 10) {
                actionButton("接收音频", enabled: session.canReceiveAudio) {
                    session.waitForAudio()
                }

                actionButton("结束录音", enabled: session.canFinishRecording) {
                    session.finishRecording()
                }
            }

            HStack(spacing: 10) {
                actionButton("AI 处理", enabled: session.canProcessAI) {
                    session.processAI()
                }

                actionButton("重置", enabled: true) {
                    session.reset()
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scanView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("蓝牙扫描")
                    .font(.headline)

                Spacer()

                Button(scanButtonTitle) {
                    session.scanDevices()
                }
                .buttonStyle(.bordered)
                .disabled(!session.canScan)
            }

            if session.scannedDevices.isEmpty {
                Text(scanEmptyText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.scannedDevices) { device in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text("RSSI \(device.rssi) · Services \(device.serviceText)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Button(deviceButtonTitle) {
                            session.connectDevice(id: device.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(session.phase.isConnectingLike || session.phase.isConnectedLike)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scanButtonTitle: String {
        session.phase == .scanning ? "停止" : "扫描"
    }

    private var scanEmptyText: String {
        if let notice = session.connectedRingNotice {
            return "\(notice)。点击“连接戒指”可接入 App。"
        }

        if session.phase == .scanning {
            return "未发现有效戒指。请确认戒指已开机、靠近手机，并且未被其他手机连接。"
        }

        if session.phase.isConnectedLike {
            return "戒指已连接。iOS 上已连接的 BLE 外设不一定继续广播。"
        }

        return "点击扫描后只显示名称含 T3 或广播 FFF0 的设备。"
    }

    private var deviceButtonTitle: String {
        session.connectedRingNotice == nil ? "连接" : "接入 App"
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("结果卡片")
                .font(.headline)

            if session.canProcessAI {
                Text("已接收真实音频")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("当前收到 \(session.packetCount) 个音频包；点击 AI 处理会先生成 WAV，再交给音频模型整理。")
                    .font(.body)

                if session.audioTranscript.isEmpty == false {
                    Text(session.audioTranscript)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                if let result = session.audioResult {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(Array(result.cards.enumerated()), id: \.offset) { _, card in
                            Text("\(card.intent.rawValue)：\(card.title)")
                                .font(.footnote)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    statusPill(title: "来源", value: "RX FFF7")
                    statusPill(title: "状态", value: session.phase.rawValue)
                }
            } else {
                Text("收到真实音频包后，这里会展示可处理状态。")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var eventLogView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("链路日志")
                .font(.headline)

            Text("日志来自 CoreBluetooth 回调和真实 TX/RX 数据。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(session.events.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .leading)

                    Text(item)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metricView(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func actionButton(
        _ title: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!enabled)
    }
}
