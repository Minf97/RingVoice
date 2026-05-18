import Foundation

struct RingAudioPacketBatch: Equatable {
    let packetCount: Int
    let byteCount: Int
    let firstPacketID: UInt16?
    let lastPacketID: UInt16?
    let droppedPacketCount: Int
    let pcmData: Data

    // 批量摘要
    func logText(totalPacketCount: Int) -> String {
        var text = "音频队列批量入账：+\(packetCount) 包，累计 \(totalPacketCount) 包，\(byteCount) bytes"

        if let firstPacketID, let lastPacketID {
            text += "，序号 \(firstPacketID)...\(lastPacketID)"
        }

        return text
    }
}

struct RingAudioBufferQueue {
    private(set) var packetCount = 0
    private(set) var byteCount = 0
    private(set) var droppedPacketCount = 0
    private(set) var pcmData = Data()
    private var pendingPacketCount = 0
    private var pendingByteCount = 0
    private var pendingDroppedPacketCount = 0
    private var pendingFirstPacketID: UInt16?
    private var pendingLastPacketID: UInt16?
    private var expectedNextPacketID: UInt16?
    private var pendingPCM = Data()

    // 写入音频包
    mutating func append(_ data: Data) {
        let packetID = Self.packetID(from: data)

        packetCount += 1
        byteCount += data.count
        pendingPacketCount += 1
        pendingByteCount += data.count

        if pendingFirstPacketID == nil {
            pendingFirstPacketID = packetID
        }
        pendingLastPacketID = packetID

        if let packetID {
            if let expectedNextPacketID, packetID != expectedNextPacketID {
                pendingDroppedPacketCount += 1
                droppedPacketCount += 1
            }
            expectedNextPacketID = packetID &+ 1
        }

        let payload = Self.pcmPayload(from: data)
        pendingPCM.append(payload)
        pcmData.append(payload)
    }

    // 取出批次
    mutating func drainPendingBatch() -> RingAudioPacketBatch? {
        guard pendingPacketCount > 0 else { return nil }

        let batch = RingAudioPacketBatch(
            packetCount: pendingPacketCount,
            byteCount: pendingByteCount,
            firstPacketID: pendingFirstPacketID,
            lastPacketID: pendingLastPacketID,
            droppedPacketCount: pendingDroppedPacketCount,
            pcmData: pendingPCM
        )

        pendingPacketCount = 0
        pendingByteCount = 0
        pendingDroppedPacketCount = 0
        pendingFirstPacketID = nil
        pendingLastPacketID = nil
        pendingPCM = Data()

        return batch
    }

    // 包序号
    private static func packetID(from data: Data) -> UInt16? {
        guard data.count >= 3 else { return nil }
        let high = UInt16(data[data.index(data.startIndex, offsetBy: 1)])
        let low = UInt16(data[data.index(data.startIndex, offsetBy: 2)])
        return high << 8 | low
    }

    // 音频载荷
    private static func pcmPayload(from data: Data) -> Data {
        guard data.count > 3 else { return Data() }
        return data.dropFirst(3)
    }
}
