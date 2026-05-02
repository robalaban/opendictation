import Foundation

nonisolated final class VoxtralEngine: @unchecked Sendable {
    enum EngineState: Sendable {
        case idle
        case loading
        case ready
        case finished(transcript: String)
        case failed(Error)
    }

    private enum ProcessPhase {
        case idle      // no process
        case warming   // process launched, model loading
        case ready     // model loaded, waiting for audio (idle timer running)
        case active    // audio being fed, transcription in progress
    }

    private let logger = DiagnosticsLogger.shared
    private let queue = DispatchQueue(label: "com.opendictation.voxtral")

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var transcript = ""
    private var isModelLoaded = false

    private var phase: ProcessPhase = .idle
    private var startRequested = false
    private var lastModelDir: String?
    private var idleTimer: DispatchSourceTimer?
    private var currentLaunchID = UUID()

    private static let idleTimeoutSeconds = 300 // 5 minutes

    var onStateChange: (@MainActor @Sendable (EngineState) -> Void)?
    var onPartialToken: (@MainActor @Sendable (String) -> Void)?

    func start(modelDir: String) {
        queue.async { [self] in
            lastModelDir = modelDir
            switch phase {
            case .ready:
                // Warm process is ready — reuse it instantly
                cancelIdleTimer()
                transcript = ""
                phase = .active
                startRequested = true
                logger.log(.voxtral, "Reusing warm process — instant start")
                notifyState(.ready)

            case .warming:
                // Process is loading model — wait for it to finish
                startRequested = true
                logger.log(.voxtral, "Model still loading — waiting for warm process")
                notifyState(.loading)

            case .idle:
                // Cold launch
                startRequested = true
                do {
                    try launchProcess(modelDir: modelDir)
                } catch {
                    logger.log(.voxtral, "Failed to launch: \(error)")
                    startRequested = false
                    notifyState(.failed(error))
                }

            case .active:
                logger.log(.voxtral, "start() called while already active — ignoring")
            }
        }
    }

    func warmUp(modelDir: String) {
        queue.async { [self] in
            guard phase == .idle else {
                logger.log(.voxtral, "warmUp called but phase is \(phase) — skipping")
                return
            }
            lastModelDir = modelDir
            startRequested = false
            do {
                try launchProcess(modelDir: modelDir)
                logger.log(.voxtral, "Pre-warming process in background")
            } catch {
                logger.log(.voxtral, "Failed to pre-warm: \(error)")
            }
        }
    }

    private func launchProcess(modelDir: String) throws {
        // Clean up readability handlers from any previous process
        self.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        self.stderrPipe?.fileHandleForReading.readabilityHandler = nil

        let launchID = UUID()
        self.currentLaunchID = launchID

        guard let bundledURL = Bundle.main.url(forResource: "voxtral", withExtension: nil) else {
            throw NSError(domain: "VoxtralEngine", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "voxtral binary not found in app bundle"])
        }
        let process = Process()
        process.executableURL = bundledURL
        process.arguments = ["-d", modelDir, "--stdin"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.transcript = ""
        self.isModelLoaded = false
        self.phase = .warming

        // READABILITY HANDLERS for stdout (tokens) — per CLAUDE.md, never use readDataToEndOfFile
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            if let text = String(data: data, encoding: .utf8) {
                self.queue.async {
                    // Only process tokens while actively transcribing
                    guard self.phase == .active else { return }
                    self.transcript += text
                    #if DEBUG
                    self.logger.log(.voxtral, "Token: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
                    #endif
                    self.notifyPartialToken(text)
                }
            }
        }

        // READABILITY HANDLERS for stderr (model loading status)
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            if let text = String(data: data, encoding: .utf8) {
                self.queue.async {
                    for line in text.split(separator: "\n") {
                        self.logger.log(.voxtral, "stderr: \(line)")
                        if line.contains("Model loaded") && !self.isModelLoaded {
                            self.isModelLoaded = true
                            if self.startRequested {
                                // User is waiting — go active
                                self.phase = .active
                                self.notifyState(.ready)
                            } else {
                                // Background warm-up — sit ready with idle timer
                                self.phase = .ready
                                self.startIdleTimer()
                            }
                        }
                    }
                }
            }
        }

        // TERMINATION HANDLER — per CLAUDE.md, use this instead of polling isRunning
        process.terminationHandler = { [weak self] proc in
            guard let self else { return }
            self.queue.async {
                guard launchID == self.currentLaunchID else {
                    self.logger.log(.voxtral, "Ignoring stale termination for PID \(proc.processIdentifier)")
                    return
                }
                let exitPhase = self.phase
                self.logger.log(.voxtral, "Process exited with code \(proc.terminationStatus), phase was \(exitPhase)")

                // Clean up readability handlers
                self.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
                self.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self.cancelIdleTimer()

                switch exitPhase {
                case .active:
                    // Normal transcription completion — emit result and auto-warm
                    self.phase = .idle
                    self.startRequested = false
                    let transcript = self.transcript
                    self.notifyState(.finished(transcript: transcript))

                    // Auto-warm the next process
                    if let modelDir = self.lastModelDir {
                        self.logger.log(.voxtral, "Auto-warming next process")
                        self.startRequested = false
                        do {
                            try self.launchProcess(modelDir: modelDir)
                        } catch {
                            self.logger.log(.voxtral, "Failed to auto-warm: \(error)")
                            self.phase = .idle
                        }
                    }

                case .warming where self.startRequested:
                    // Process crashed while user was waiting for model to load
                    self.phase = .idle
                    self.startRequested = false
                    self.notifyState(.failed(NSError(domain: "VoxtralEngine", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Process crashed during model loading"])))

                case .warming, .ready:
                    // Warm process died (killed by timer, crashed, etc.) — just clean up
                    self.phase = .idle
                    self.startRequested = false
                    self.logger.log(.voxtral, "Warm process ended — no action needed")

                case .idle:
                    // Already cleaned up (cancel was called before termination handler ran)
                    break
                }
            }
        }

        try process.run()
        logger.log(.voxtral, "Process launched, PID: \(process.processIdentifier)")

        if startRequested {
            notifyState(.loading)
        }

        // CRITICAL: Close parent write-ends on stdout/stderr after process.run() — per CLAUDE.md
        try stdoutPipe.fileHandleForWriting.close()
        try stderrPipe.fileHandleForWriting.close()
    }

    func feedAudio(_ data: Data) {
        queue.async { [self] in
            guard phase == .active, let handle = stdinPipe?.fileHandleForWriting else { return }
            handle.write(data)
        }
    }

    func finishAudio() {
        queue.async { [self] in
            logger.log(.voxtral, "Closing stdin")
            try? stdinPipe?.fileHandleForWriting.close()
        }
    }

    func cancel() {
        queue.async { [self] in
            cancelIdleTimer()
            startRequested = false
            if let process, process.isRunning {
                phase = .idle // Set before terminate so terminationHandler knows
                process.terminate()
                logger.log(.voxtral, "Process terminated via cancel()")
            } else {
                phase = .idle
            }
        }
    }

    // MARK: - Idle Timer

    private func startIdleTimer() {
        cancelIdleTimer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(Self.idleTimeoutSeconds))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.logger.log(.voxtral, "Idle timeout — killing warm process")
            self.cancelWarmProcess()
        }
        timer.resume()
        idleTimer = timer
        logger.log(.voxtral, "Idle timer started (\(Self.idleTimeoutSeconds)s)")
    }

    private func cancelIdleTimer() {
        idleTimer?.cancel()
        idleTimer = nil
    }

    private func cancelWarmProcess() {
        guard phase == .warming || phase == .ready else { return }
        phase = .idle
        if let process, process.isRunning {
            process.terminate()
            logger.log(.voxtral, "Warm process killed")
        }
    }

    // MARK: - Notifications

    private func notifyState(_ state: EngineState) {
        let callback = onStateChange
        Task { @MainActor in
            callback?(state)
        }
    }

    private func notifyPartialToken(_ token: String) {
        let callback = onPartialToken
        Task { @MainActor in
            callback?(token)
        }
    }
}
