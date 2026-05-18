import Foundation

struct RingScannedDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
    let serviceText: String
    let isRingCandidate: Bool
}

enum RingScanMode {
    case browsing
    case connectingRing
}
