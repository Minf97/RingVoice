import SwiftUI

struct ContentView: View {
    @StateObject private var session = RingBluetoothSession()
    @State private var dismissedSheetDeviceID: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                MainWorkflowView()
                    .tabItem {
                        Label("主链路", systemImage: "sparkles")
                    }

                DebugLabView(session: session)
                    .tabItem {
                        Label("测试页", systemImage: "antenna.radiowaves.left.and.right")
                    }
            }

            if let device = connectionSheetDevice {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSheet(device.id)
                    }
                    .transition(.opacity)
                    .zIndex(1)

                RingDeviceConnectionSheet(
                    device: device,
                    phaseText: session.phase.rawValue,
                    isBusy: session.phase == .connecting || session.phase == .discovering,
                    isConnected: session.phase == .connected,
                    onConnect: {
                        session.connectDevice(id: device.id)
                    },
                    onDismiss: {
                        dismissSheet(device.id)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.24), value: connectionSheetDevice?.id)
    }

    private var connectionSheetDevice: RingScannedDevice? {
        guard let device = session.scannedDevices.first else { return nil }
        return dismissedSheetDeviceID == device.id ? nil : device
    }

    private func dismissSheet(_ deviceID: UUID) {
        withAnimation(.easeOut(duration: 0.24)) {
            dismissedSheetDeviceID = deviceID
        }
    }
}
