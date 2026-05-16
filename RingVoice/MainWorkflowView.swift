import SwiftUI

// API 索引:
// LazyVStack 懒加载纵向列表。Docs: https://developer.apple.com/documentation/swiftui/lazyvstack
// ScrollView 页面滚动容器。Docs: https://developer.apple.com/documentation/swiftui/scrollview
// Button 触发用户动作。Docs: https://developer.apple.com/documentation/swiftui/button
// Image 展示系统图标。Docs: https://developer.apple.com/documentation/swiftui/image
// withAnimation 包裹状态动画。Docs: https://developer.apple.com/documentation/swiftui/withanimation(_:_:)
// Sheet 弹出编辑面板。Docs: https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:)
// ProgressView 展示加载状态。Docs: https://developer.apple.com/documentation/swiftui/progressview

struct MainWorkflowView: View {
    // API: @State 保存主链路状态，变化后自动刷新界面。
    // Docs: https://developer.apple.com/documentation/swiftui/state
    @State private var workflow = VoiceWorkflow()
    @State private var isEditorPresented = false
    @State private var isGenerating = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                heroSection
                ringCaptureSection
                transcriptSection
                aiSection
                cardsSection
            }
            .padding(18)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isEditorPresented) {
            TranscriptEditorSheet(transcript: $workflow.transcript)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RingVoice")
                .font(.system(size: 34, weight: .bold))

            Text("把戒指录音整理成可执行的索引卡。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                statusBadge("语音转文字", isReady: workflow.canProcess)
                statusBadge("AI 润色", isReady: workflow.stage == .processed)
                statusBadge("索引卡", isReady: workflow.cards.isEmpty == false)
            }
        }
        .padding(.top, 24)
    }

    private var ringCaptureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle("戒指录音入口")

                    Text("Demo 里先用按钮模拟戒指按下、录音上传和语音转文字。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                primaryButton("模拟录音") {
                    workflow.loadSampleTranscript()
                    errorText = nil
                }

                secondaryButton("重置") {
                    workflow.reset()
                    errorText = nil
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("转写文本")

                Spacer()

                Button("编辑") {
                    isEditorPresented = true
                }
                .font(.subheadline)
                .disabled(!workflow.canProcess)
            }

            Text(workflow.canProcess ? workflow.transcript : "等待戒指录音上传后生成文本。")
                .font(.body)
                .foregroundStyle(workflow.canProcess ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            primaryButton(isGenerating ? "AI 处理中" : "AI 总结成卡") {
                Task {
                    await generateWithAI()
                }
            }
            .disabled(!workflow.canProcess || isGenerating)

            if isGenerating {
                ProgressView("正在调用阶跃 API")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("AI 润色与总结")

            if workflow.stage == .processed {
                resultBlock(title: "润色文本", bodyText: workflow.polishedText)
                resultBlock(title: "内容总结", bodyText: workflow.summary)
            } else {
                Text("点击“AI 总结成卡”后，这里会展示润色后的文本和一句话总结。")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("索引卡")

            if workflow.cards.isEmpty {
                emptyCard
            } else {
                ForEach(workflow.cards) { card in
                    insightCard(card)
                }
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("暂无卡片")
                .font(.headline)

            Text("AI 会把语音内容拆成 TODO、定时和长期素材。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func insightCard(_ card: InsightCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusBadge(card.intent.rawValue, isReady: true)

                Spacer()

                if let timeText = card.timeText {
                    Text(timeText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }

            Text(card.title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(card.detail)
                .font(.body)
                .foregroundStyle(.secondary)

            Button(card.actionTitle) {}
                .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func resultBlock(title: String, bodyText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(bodyText)
                .font(.body)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
    }

    private func statusBadge(_ title: String, isReady: Bool) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isReady ? Color.green.opacity(0.14) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isReady ? .green : .secondary)
            .clipShape(Capsule())
    }

    // 真实 AI
    @MainActor
    private func generateWithAI() async {
        isGenerating = true
        errorText = nil

        do {
            let client = try StepAIClient.fromEnvironment()
            let result = try await client.generateInsights(from: workflow.transcript)

            withAnimation(.easeOut(duration: 0.22)) {
                workflow.applyAIResult(result)
            }
        } catch {
            errorText = error.localizedDescription
        }

        isGenerating = false
    }
}
