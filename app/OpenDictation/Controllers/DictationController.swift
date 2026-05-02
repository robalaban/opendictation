import AppKit
import Foundation

@Observable
final class DictationController {
    enum State: Equatable {
        case idle
        case recording
        case transcribing
        case done
    }

    private(set) var state: State = .idle
    private let logger = DiagnosticsLogger.shared
    private let settings = AppSettings.shared

    let overlay = OverlayController()
    let store = DictationStore()

    private let audioRecorder = AudioRecorder()
    private let voxtralEngine = VoxtralEngine()
    private let textInjector = TextInjector()

    private(set) var inAppNoteID: UUID?
    var onSelectNote: ((UUID) -> Void)?

    private var injectionTarget: TextInjector.Target?
    private var recordingStartTime: Date?
    private var audioBuffer = Data()
    private var partialTranscript = ""
    private var smoothedAmplitude: Float = 0

    func setup() {
        overlay.setup()

        // onAudioData fires on the audio thread (NOT MainActor).
        // voxtralEngine.feedAudio is nonisolated and dispatches to its own queue — safe to call directly.
        // audioBuffer and overlay are @MainActor, so access them via Task { @MainActor in }.
        let saveAudio = settings.saveAudioRecordings
        audioRecorder.onAudioData = { [weak self] pcm16Data, amplitude in
            guard let self else { return }
            self.voxtralEngine.feedAudio(pcm16Data)
            Task { @MainActor in
                if saveAudio {
                    self.audioBuffer.append(pcm16Data)
                }
                // Exponential smoothing: rise fast on speech, fall slowly on silence
                let factor: Float = amplitude > self.smoothedAmplitude ? 0.6 : 0.15
                self.smoothedAmplitude += factor * (amplitude - self.smoothedAmplitude)
                self.overlay.showListening(amplitude: self.smoothedAmplitude)
            }
        }

        // VoxtralEngine callbacks are already dispatched to @MainActor
        voxtralEngine.onStateChange = { [weak self] engineState in
            guard let self else { return }
            switch engineState {
            case .loading:
                self.logger.log(.voxtral, "Model loading...")
            case .ready:
                self.logger.log(.voxtral, "Model ready — starting audio capture")
                self.startAudioCapture()
            case .finished(let transcript):
                self.logger.log(.voxtral, "Transcription complete: \(transcript.prefix(50))...")
                self.handleTranscriptionComplete(transcript: transcript)
            case .failed(let error):
                self.logger.log(.voxtral, "Engine failed: \(error)")
                let message = error.localizedDescription.contains("model loading")
                    ? "Model not found — check Settings"
                    : "Transcription failed"
                self.overlay.showError(message: message)
                self.state = .idle
            case .idle:
                break
            }
        }

        voxtralEngine.onPartialToken = { [weak self] token in
            guard let self else { return }
            self.partialTranscript += token
            if self.state == .recording {
                if let noteID = self.inAppNoteID {
                    // In-app: update the note's transcript live
                    self.store.updateTranscript(id: noteID, transcript: self.partialTranscript)
                } else {
                    // External: type into focused app
                    self.textInjector.typeLive(text: token)
                }
            }
        }
    }

    func toggle() {
        switch state {
        case .idle:
            startDictation()
        case .recording:
            stopDictation()
        case .transcribing, .done:
            logger.log(.hotkey, "Ignoring hotkey in state: \(state)")
        }
    }

    private func startDictation() {
        logger.log(.app, "Starting dictation")
        NSSound(named: "Ping")?.play()
        state = .recording

        recordingStartTime = Date()
        audioBuffer = Data()
        partialTranscript = ""
        smoothedAmplitude = 0

        if NSApp.isActive {
            // In-app dictation — create note, show live transcript
            let id = store.createBlank()
            inAppNoteID = id
            onSelectNote?(id)
            injectionTarget = nil
            logger.log(.app, "In-app dictation — note \(id)")
        } else {
            // External dictation — inject into focused app
            injectionTarget = textInjector.captureTarget()
            inAppNoteID = nil
        }

        overlay.showLoading()
        voxtralEngine.start(modelDir: settings.modelDirectory)
    }

    private func startAudioCapture() {
        do {
            try audioRecorder.start()
            overlay.showListening(amplitude: 0)
        } catch {
            logger.log(.audio, "Failed to start audio: \(error)")
            voxtralEngine.cancel()
            overlay.hide()
            state = .idle
        }
    }

    private var transcribingStartTime: Date?

    private func stopDictation() {
        logger.log(.app, "Stopping dictation")
        state = .transcribing
        transcribingStartTime = Date()

        audioRecorder.stop()
        overlay.showTranscribing(partialText: partialTranscript)

        voxtralEngine.finishAudio()
    }

    private func handleTranscriptionComplete(transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
            let wavData = settings.saveAudioRecordings ? buildWAV(from: audioBuffer) : nil

            if let noteID = inAppNoteID {
                // In-app dictation — update existing note
                store.updateTranscript(id: noteID, transcript: trimmed)
                store.finalize(id: noteID, duration: duration, audioData: wavData)
            } else {
                // External dictation — save new note
                store.save(transcript: trimmed, duration: duration, audioData: wavData)
            }
        } else {
            logger.log(.app, "Empty transcript")
            // Clean up blank note if in-app
            if let noteID = inAppNoteID {
                store.permanentlyDelete(id: noteID)
            }
        }

        inAppNoteID = nil

        // Ensure the processing pill is visible for at least 800ms
        let elapsed = transcribingStartTime.map { Date().timeIntervalSince($0) } ?? 1.0
        let remaining = max(0.5 - elapsed, 0)
        Task { @MainActor in
            if remaining > 0 {
                try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
            }
            overlay.showSuccess()
            NSSound(named: "Glass")?.play()
            state = .idle
        }
    }

    private func buildWAV(from pcm16: Data) -> Data? {
        guard !pcm16.isEmpty else { return nil }
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcm16.count)
        let fileSize = 36 + dataSize

        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        wav.append(contentsOf: "data".utf8)
        wav.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wav.append(pcm16)
        return wav
    }
}
