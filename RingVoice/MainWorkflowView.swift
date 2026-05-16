import SwiftUI

struct MainWorkflowView: View {
    @State private var workflow = VoiceWorkflow()
    @StateObject private var recorder = PhoneSpeechRecorder()
    @State private var isGenerating = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    cardsSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .background(BrandColor.canvas.ignoresSafeArea())
            .navigationTitle("RingVoice")
            .safeAreaInset(edge: .bottom) {
                recorderBar
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("索引卡")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(BrandColor.ink)

            if workflow.cards.isEmpty {
                emptyIndexCard
            } else {
                ForEach(workflow.cards) { card in
                    indexCard(card)
                }
            }
        }
    }

    private var emptyIndexCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            intentPill("待录音")

            Text("还没有索引卡")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(BrandColor.ink)

            Text("点击底部按钮，用手机录音；戒指录音接入同一条 AI 处理链路。")
                .font(.body)
                .foregroundStyle(BrandColor.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(BrandColor.canvasSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func indexCard(_ card: InsightCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                intentPill(card.intent.rawValue)

                Spacer()

                if let timeText = card.timeText {
                    Text(timeText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(BrandColor.body)
                }
            }

            Text(card.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(BrandColor.ink)

            Text(card.detail)
                .font(.body)
                .foregroundStyle(BrandColor.body)

            Button(card.actionTitle) {}
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(BrandColor.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(BrandColor.canvasSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recorderBar: some View {
        VStack(spacing: 10) {
            if let statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .multilineTextAlignment(.center)
            }

            Button {
                toggleRecording()
            } label: {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: recorder.phase.isRecording ? "stop.fill" : "mic.fill")
                    }

                    Text(recordButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .foregroundStyle(.white)
                .background(recordButtonColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGenerating)
            .accessibilityLabel(recordButtonTitle)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(BrandColor.canvas)
    }

    private var statusText: String? {
        if let errorText {
            return errorText
        }

        if case .failed(let message) = recorder.phase {
            return message
        }

        if recorder.phase.isRecording {
            return recorder.transcript.isEmpty ? "正在听你说话" : recorder.transcript
        }

        if isGenerating {
            return "正在润色并生成索引卡"
        }

        return nil
    }

    private var statusColor: Color {
        if errorText != nil {
            return .red
        }

        if case .failed = recorder.phase {
            return .red
        }

        return BrandColor.body
    }

    private var recordButtonTitle: String {
        if isGenerating {
            return "处理中"
        }

        return recorder.phase.isRecording ? "结束录音" : "手机录音"
    }

    private var recordButtonColor: Color {
        recorder.phase.isRecording ? BrandColor.ink : BrandColor.primary
    }

    private func intentPill(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(BrandColor.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(BrandColor.canvas)
            .clipShape(Capsule())
    }

    // 录音切换
    private func toggleRecording() {
        Task {
            do {
                if recorder.phase.isRecording {
                    try await finishPhoneRecording()
                } else {
                    try await startPhoneRecording()
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    // 手机开始
    @MainActor
    private func startPhoneRecording() async throws {
        workflow.reset()
        errorText = nil
        try await recorder.start()
    }

    // 手机结束
    @MainActor
    private func finishPhoneRecording() async throws {
        let transcript = try recorder.stop()
        workflow.setTranscript(transcript)
        try await generateWithAI()
    }

    // AI 处理
    @MainActor
    private func generateWithAI() async throws {
        isGenerating = true
        defer { isGenerating = false }

        let client = try StepAIClient.fromEnvironment()
        let result = try await client.generateInsights(from: workflow.transcript)

        withAnimation(.easeOut(duration: 0.22)) {
            workflow.applyAIResult(result)
        }
    }
}

private enum BrandColor {
    static let primary = Color(red: 1, green: 0.31, blue: 0)
    static let ink = Color(red: 0.13, green: 0.08, blue: 0.08)
    static let body = Color(red: 0.38, green: 0.36, blue: 0.32)
    static let canvas = Color(red: 1, green: 1, blue: 0.98)
    static let canvasSoft = Color(red: 0.97, green: 0.96, blue: 0.94)
}
