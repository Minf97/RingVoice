import SwiftUI

// API: @main 标记应用入口，系统从这里启动 App。
// Docs: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#main
@main
// API: SwiftUI.App 定义应用生命周期和首个场景。
// Docs: https://developer.apple.com/documentation/swiftui/app
struct HelloWorldApp: App {
    var body: some Scene {
        // API: WindowGroup 创建应用主窗口，并承载根视图。
        // Docs: https://developer.apple.com/documentation/swiftui/windowgroup
        WindowGroup {
            ContentView()
        }
    }
}
