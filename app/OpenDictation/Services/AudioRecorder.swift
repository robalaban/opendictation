import AVFoundation

nonisolated final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let logger = DiagnosticsLogger.shared
    private var isRecording = false

    var onAudioData: ((_ pcm16Data: Data, _ amplitude: Float) -> Void)?

    func start() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        logger.log(.audio, "Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                sampleRate: 16000,
                                                channels: 1,
                                                interleaved: false) else {
            throw AudioError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                                          frameCapacity: frameCapacity) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status == .haveData, error == nil,
                  let floatData = convertedBuffer.floatChannelData?[0] else { return }

            let frameCount = Int(convertedBuffer.frameLength)

            // Compute amplitude (RMS)
            var sum: Float = 0
            for i in 0..<frameCount {
                sum += floatData[i] * floatData[i]
            }
            let rms = sqrt(sum / Float(max(frameCount, 1)))
            let amplitude = min(pow(rms * 10.0, 0.5), 1.0)

            // Convert float32 to s16le — pre-allocate to avoid per-sample Data allocs on audio thread
            var pcm16 = Data(count: frameCount * 2)
            pcm16.withUnsafeMutableBytes { raw in
                let ptr = raw.bindMemory(to: Int16.self)
                for i in 0..<frameCount {
                    ptr[i] = Int16(max(-1.0, min(1.0, floatData[i])) * 32767)
                }
            }

            self.onAudioData?(pcm16, amplitude)
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }
        isRecording = true
        logger.log(.audio, "Recording started")
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        logger.log(.audio, "Recording stopped")
    }

    enum AudioError: Error {
        case formatError
        case converterError
    }
}
