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
    // API: @State 保存本页本地状态，状态变化会触发界面刷新。
    // Docs: https://developer.apple.com/documentation/swiftui/state
    @State private var session = DemoSession()

    var body: some View {
        // API: ScrollView 让页面内容可滚动，适合手机小屏展示工作台。
        // Docs: https://developer.apple.com/documentation/swiftui/scrollview
        ScrollView {
            // API: VStack 纵向排列多个区域。
            // Docs: https://developer.apple.com/documentation/swiftui/vstack
            VStack(alignment: .leading, spacing: 16) {
                headerView
                statusView
                actionView
                resultView
                PromptLabView()
                eventLogView
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ring Voice Demo")
                .font(.system(size: 30, weight: .bold))

            Text("先用本地状态模拟蓝牙戒指、录音、AI 分类和提醒创建。")
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
                statusPill(title: "电量", value: "\(session.battery)%")
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
            Text("模拟链路")
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
                    session.receiveAudioPackets()
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

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("结果卡片")
                .font(.headline)

            if session.phase == .ready {
                Text(session.resultTitle)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(session.polishedText)
                    .font(.body)

                HStack(spacing: 8) {
                    statusPill(title: "意图", value: session.intent.rawValue)
                    statusPill(title: "提醒", value: session.reminderText)
                }
            } else {
                Text("完成 AI 处理后，这里会展示润色文本和意图分类。")
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
            Text("数据流日志")
                .font(.headline)

            // API: ForEach 遍历日志数组，并为每条日志生成 Text。
            // Docs: https://developer.apple.com/documentation/swiftui/foreach
            ForEach(session.events, id: \.self) { item in
                Text(item)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
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
