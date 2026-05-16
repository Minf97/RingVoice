import SwiftUI

// API 索引:
// TextEditor 输入长文本。Docs: https://developer.apple.com/documentation/swiftui/texteditor
// NavigationStack 承载导航页。Docs: https://developer.apple.com/documentation/swiftui/navigationstack
// ToolbarItem 放置导航按钮。Docs: https://developer.apple.com/documentation/swiftui/toolbaritem

struct TranscriptEditorSheet: View {
    // API: @Environment 读取系统注入能力，这里用来关闭弹窗。
    // Docs: https://developer.apple.com/documentation/swiftui/environment
    @Environment(\.dismiss) private var dismiss

    // API: @Binding 接收父视图状态引用，编辑会同步回主页面。
    // Docs: https://developer.apple.com/documentation/swiftui/binding
    @Binding var transcript: String

    var body: some View {
        NavigationStack {
            TextEditor(text: $transcript)
                .font(.body)
                .padding()
                .navigationTitle("编辑转写")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
