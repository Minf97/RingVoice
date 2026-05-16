import SwiftUI

// API: TabView 创建底部标签页，用来区分主链路和测试页。
// Docs: https://developer.apple.com/documentation/swiftui/tabview
struct ContentView: View {
    var body: some View {
        TabView {
            MainWorkflowView()
                .tabItem {
                    // API: Label 组合图标和文字，适合 Tab 标识。
                    // Docs: https://developer.apple.com/documentation/swiftui/label
                    Label("主链路", systemImage: "sparkles")
                }

            DebugLabView()
                .tabItem {
                    Label("测试页", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
    }
}

