import Foundation

enum RingWAVEncoderError: LocalizedError {
    case emptyPCM

    var errorDescription: String? {
        switch self {
        case .emptyPCM:
            "没有可编码的 PCM 数据"
        }
    }
}

struct RingWAVEncoder {
    // 生成 WAV
    static func encode(
        pcmData: Data,
        sampleRate: Int = 16_000,
        channels: Int = 1,
        bitsPerSample: Int = 16
    ) throws -> Data {
        guard pcmData.isEmpty == false else {
            throw RingWAVEncoderError.emptyPCM
        }

        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcmData.count
        let riffSize = 36 + dataSize

        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(leUInt32(UInt32(riffSize)))
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(leUInt32(16))
        wav.append(leUInt16(1))
        wav.append(leUInt16(UInt16(channels)))
        wav.append(leUInt32(UInt32(sampleRate)))
        wav.append(leUInt32(UInt32(byteRate)))
        wav.append(leUInt16(UInt16(blockAlign)))
        wav.append(leUInt16(UInt16(bitsPerSample)))
        wav.append(contentsOf: "data".utf8)
        wav.append(leUInt32(UInt32(dataSize)))
        wav.append(pcmData)
        return wav
    }

    // 小端写入
    private static func leUInt16(_ value: UInt16) -> Data {
        var value = value.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }

    // 小端写入
    private static func leUInt32(_ value: UInt32) -> Data {
        var value = value.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}
