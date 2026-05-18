import SwiftUI

// API 索引:
// Text 显示文字。Docs: https://developer.apple.com/documentation/swiftui/text
// Color 设置颜色。Docs: https://developer.apple.com/documentation/swiftui/color
// ForEach 渲染集合。Docs: https://developer.apple.com/documentation/swiftui/foreach
// RoundedRectangle 绘制圆角背景。Docs: https://developer.apple.com/documentation/swiftui/roundedrectangle
// View modifiers 调整样式。Docs: https://developer.apple.com/documentation/swiftui/view

// API: SwiftUI.View 定义界面声明入口。
// Docs: https://developer.apple.com/documentation/swiftui/view
struct DebugLabView: View {
    // API: @StateObject 持有蓝牙会话，回调变化会刷新界面。
    // Docs: https://developer.apple.com/documentation/swiftui/stateobject
    @StateObject private var session = RingBluetoothSession()

    var body: some View {
        // API: ScrollView 让页面内容可滚动，适合手机小屏展示工作台。
        // Docs: https://developer.apple.com/documentation/swiftui/scrollview
        ScrollView {
            // API: VStack 纵向排列多个区域。
            // Docs: https://developer.apple.com/documentation/swiftui/vstack
            VStack(alignment: .leading, spacing: 16) {
                headerView
                statusView
                scanView
                actionView
                eventLogView
                resultView
                PromptLabView()
            }
            .padding(18)
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

            // API: HStack 横向排列状态信息。
            // Docs: https://developer.apple.com/documentation/swiftui/hstack
            HStack(spacing: 12) {
                statusPill(title: "连接", value: session.connectionText)
                statusPill(title: "阶段", value: session.phase.rawValue)
                statusPill(title: "电量", value: "--")
            }

            HStack(spacing: 12) {
                metricView(title: "音频包", value: "\(session.packetCount)")
                metricView(title: "震动", value: session.didVibrate ? "已触发" : "未触发")
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

                Button("扫描") {
                    session.scanDevices()
                }
                .buttonStyle(.bordered)
                .disabled(!session.canScan)

                Button("停止") {
                    session.stopScan()
                }
                .buttonStyle(.bordered)
                .disabled(session.phase != .scanning)
            }

            if session.scannedDevices.isEmpty {
                Text("点击扫描后只显示名称含 T3 或广播 FFF0 的设备。")
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

                        Button("连接") {
                            session.connectDevice(id: device.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(session.phase == .connecting || session.phase == .discovering)
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

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("结果卡片")
                .font(.headline)

            if session.canProcessAI {
                Text("已接收真实音频")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("当前收到 \(session.packetCount) 个音频包；下一步可把 PCM 缓存接入 WAV 和 STT。")
                    .font(.body)

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

            // API: ForEach 遍历日志数组，并为每条日志生成 Text。
            // Docs: https://developer.apple.com/documentation/swiftui/foreach
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
        // API: Button 响应用户点击，触发本地状态变更。
        // Docs: https://developer.apple.com/documentation/swiftui/button
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
