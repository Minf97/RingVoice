import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MainWorkflowView()
                .tabItem {
                    Label("主链路", systemImage: "sparkles")
                }

            DebugLabView()
                .tabItem {
                    Label("测试页", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
    }
}
