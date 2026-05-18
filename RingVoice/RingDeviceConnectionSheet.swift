import SwiftUI

struct RingDeviceConnectionSheet: View {
    let device: RingScannedDevice
    let phaseText: String
    let isBusy: Bool
    let isConnected: Bool
    let onConnect: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                sheetContent

                // 安全区填充
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(height: proxy.safeAreaInsets.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .offset(y: max(dragOffset, 0))
            .gesture(dismissDrag)
            .ignoresSafeArea(edges: .bottom)
            .onAppear {
                // startRotation()
            }
        }
        .frame(height: 430)
    }

    private var sheetContent: some View {
        VStack(spacing: 18) {
            grabber
            titleRow
            productImage

            HStack(spacing: 10) {
                statusChip("RSSI", "\(device.rssi)")
                statusChip("Service", device.serviceText)
            }

            connectButton
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 28,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: 28
                ),
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: -8)
    }

    private var titleRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityLabel("关闭戒指连接弹窗")
        }
    }

    private var connectButton: some View {
        Button(action: onConnect) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                }

                Text(buttonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isBusy || isConnected)
        .accessibilityHint("连接扫描到的蓝牙戒指")
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 42, height: 5)
            .accessibilityHidden(true)
    }

    private var productImage: some View {
        Image("RingProduct")
            .resizable()
            .scaledToFit()
            .frame(width: 144, height: 180)
            .accessibilityLabel("蓝牙戒指")
    }

    private var statusText: String {
        if isConnected {
            return "已连接，等待按下戒指"
        }

        return phaseText
    }

    private var buttonTitle: String {
        if isConnected {
            return "已连接"
        }

        return isBusy ? "连接中" : "连接"
    }

    private func statusChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.monospaced())
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = max(value.translation.height, 0)
            }
            .onEnded { value in
                if value.translation.height > 80 || value.predictedEndTranslation.height > 140 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }

}
