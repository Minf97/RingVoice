import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Hello, world!")
                .font(.title)
                .fontWeight(.semibold)
        }
        .padding()
    }
}
