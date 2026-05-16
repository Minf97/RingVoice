import SwiftUI

// API 索引:
// TextEditor 输入提示词。Docs: https://developer.apple.com/documentation/swiftui/texteditor
// ProgressView 展示加载状态。Docs: https://developer.apple.com/documentation/swiftui/progressview
// Task 启动异步任务。Docs: https://developer.apple.com/documentation/swift/task
// ScrollViewReader 控制滚动位置。Docs: https://developer.apple.com/documentation/swiftui/scrollviewreader

struct PromptLabView: View {
    // API: @State 保存提示词实验状态。
    // Docs: https://developer.apple.com/documentation/swiftui/state
    @State private var systemPrompt = PromptLabDefaults.systemPrompt
    @State private var draftMessage = PromptLabDefaults.userMessage
    @State private var messages: [PromptLabMessage] = []
    @State private var isSending = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提示词实验")
                .font(.headline)

            Text("修改 system prompt 后，在聊天框里自由输入，连续观察模型输出差异。")
                .font(.body)
                .foregroundStyle(.secondary)

            editorBlock(title: "System Prompt", text: $systemPrompt, height: 118)
            messageList
            chatInput
            actionRow
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Text(isSending ? "发送中" : "发送测试")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending || trimmedDraft.isEmpty)

            Button {
                resetPrompt()
            } label: {
                Text("清空")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(isSending)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if messages.isEmpty {
                        Text("还没有对话，先在下面输入一条消息。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .onChange(of: messages) { _, newValue in
                    guard let last = newValue.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: 260)
    }

    private var chatInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("聊天输入")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextEditor(text: $draftMessage)
                .font(.body)
                .frame(height: 78)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if isSending {
                ProgressView("正在调用阶跃 API")
                    .font(.caption)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func messageBubble(_ message: PromptLabMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(message.content)
                .font(.body)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == "user" ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func editorBlock(title: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextEditor(text: text)
                .font(.body)
                .frame(height: height)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // 发送测试
    @MainActor
    private func sendMessage() async {
        let content = trimmedDraft
        let userMessage = PromptLabMessage(role: "user", content: content)

        isSending = true
        errorText = nil
        draftMessage = ""
        messages.append(userMessage)

        do {
            let client = try StepAIClient.fromEnvironment()
            let reply = try await client.chat(systemPrompt: systemPrompt, messages: apiMessages)
            messages.append(.init(role: "assistant", content: reply))
        } catch {
            errorText = error.localizedDescription
        }

        isSending = false
    }

    // 还原提示
    private func resetPrompt() {
        systemPrompt = PromptLabDefaults.systemPrompt
        draftMessage = PromptLabDefaults.userMessage
        messages = []
        errorText = nil
    }

    private var trimmedDraft: String {
        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var apiMessages: [AIChatMessage] {
        messages.map { .init(role: $0.role, content: $0.content) }
    }
}

struct PromptLabMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    let content: String

    var title: String {
        role == "user" ? "User" : "Assistant"
    }
}

enum PromptLabDefaults {
    static let systemPrompt = """
    You are a concise product assistant for an IoT voice ring demo.
    Explain how the user's message should become actionable app data.
    Keep the answer short and practical.
    """

    static let userMessage = """
    Tomorrow at 3 PM, remind me to send the proposal to the client.
    Also check the pricing section before sending it.
    """
}
