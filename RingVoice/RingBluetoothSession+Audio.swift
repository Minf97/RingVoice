import Dispatch
import Foundation

extension RingBluetoothSession {
    // 开始录音
    func startRecording() {
        audioQueue = RingAudioBufferQueue()
        packetCount = 0
        audioTranscript = ""
        audioResult = nil
        enqueue([RingBluetoothCommands.startAudio])
    }

    // 等待音频
    func waitForAudio() {
        guard phase == .recording || phase == .receiving else {
            events.append("未进入录音状态，不能接收音频")
            return
        }

        events.append("等待 RX FFF7 推送音频包")
    }

    // 结束录音
    func finishRecording() {
        enqueue([
            RingBluetoothCommands.stopAudio,
            RingBluetoothCommands.vibrate200ms
        ])
    }

    // AI 处理
    func processAI() {
        flushAudioQueue()

        let wavData: Data
        do {
            wavData = try buildQueuedWAV()
        } catch {
            markFailed("WAV 生成失败：\(error.localizedDescription)")
            return
        }

        events.append("WAV 已生成：\(wavData.count) bytes，准备发送音频 AI")

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let client = try StepAudioAIClient.fromEnvironment()
                let output = try await client.generateUnderstanding(fromWAVData: wavData)
                self.audioResult = output.result
                self.audioTranscript = output.text
                if output.result == nil {
                    self.events.append("音频 AI 返回文本，未生成结构化卡片")
                } else {
                    self.events.append("音频 AI 处理成功")
                }
            } catch {
                self.events.append("音频 AI 处理失败：\(error.localizedDescription)")
                self.markFailed(error.localizedDescription)
            }
        }
    }

    func handleReceived(_ data: Data) {
        guard let first = data.first else { return }
        if first == 0xCA, data.count > 16 {
            handleAudioPacket(data)
            return
        }

        events.append("接收 RX：\(data.ringHexText)")
        handleControlPacket(data)
    }

    // 音频包入队
    private func handleAudioPacket(_ data: Data) {
        audioQueue.append(data)
        phase = .receiving
        scheduleAudioFlush()
    }

    // 控制包处理
    private func handleControlPacket(_ data: Data) {
        guard data.count > 1, data.first == 0xC9 else { return }

        let code = data[data.index(data.startIndex, offsetBy: 1)]
        if code == 0x03 {
            phase = .recording
            events.append("戒指确认开始录音：0xC9 03")
        } else if code == 0x04 {
            flushAudioQueue()
            phase = .ready
            events.append("戒指确认音频结束：0xC9 04")
        }
    }

    // 定时刷新
    private func scheduleAudioFlush() {
        guard audioFlushWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.flushAudioQueue()
            }
        }
        audioFlushWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    // 生成 WAV
    func buildQueuedWAV() throws -> Data {
        try RingWAVEncoder.encode(pcmData: audioQueue.pcmData)
    }

    // 刷新队列
    func flushAudioQueue() {
        audioFlushWorkItem?.cancel()
        audioFlushWorkItem = nil
        guard let batch = audioQueue.drainPendingBatch() else { return }
        packetCount = audioQueue.packetCount
        events.append(batch.logText(totalPacketCount: audioQueue.packetCount))
    }
}
