import Foundation

@Observable
final class DictationStore {
    private(set) var dictations: [Dictation] = []
    private let logger = DiagnosticsLogger.shared
    private let baseDir: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDir = appSupport.appendingPathComponent("OpenDictation/Dictations")
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        Task { await loadAllAsync() }
    }

    private func loadAllAsync() async {
        let base = baseDir
        let loaded: [Dictation] = await Task.detached {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else { return [] }
            return contents.compactMap { dir -> Dictation? in
                let metaURL = dir.appendingPathComponent("meta.json")
                let textURL = dir.appendingPathComponent("dictation.md")
                guard let metaData = try? Data(contentsOf: metaURL),
                      let meta = try? JSONDecoder().decode(DictationMeta.self, from: metaData),
                      let text = try? String(contentsOf: textURL, encoding: .utf8) else { return nil }
                return Dictation(meta: meta, transcript: text)
            }.sorted { $0.date > $1.date }
        }.value
        dictations = loaded
        purgeExpired()
        logger.log(.store, "Loaded \(dictations.count) dictations")
    }

    // MARK: - Filtered Accessors

    var activeNotes: [Dictation] {
        dictations.filter { !$0.isDeleted }
    }

    var recentNotes: [Dictation] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return activeNotes.filter { $0.date > sevenDaysAgo }
    }

    var trashedNotes: [Dictation] {
        dictations.filter { $0.isDeleted }
    }

    // MARK: - Save (external dictation)

    func save(transcript: String, duration: TimeInterval, audioData: Data?) {
        let meta = DictationMeta(duration: duration, hasAudio: audioData != nil)
        let dir = baseDir.appendingPathComponent(meta.id.uuidString)

        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let metaData = try JSONEncoder().encode(meta)
            try metaData.write(to: dir.appendingPathComponent("meta.json"))
            try transcript.write(to: dir.appendingPathComponent("dictation.md"),
                                  atomically: true, encoding: .utf8)
            if let audioData {
                try audioData.write(to: dir.appendingPathComponent("audio.wav"))
            }

            let dictation = Dictation(meta: meta, transcript: transcript)
            dictations.insert(dictation, at: 0)
            logger.log(.store, "Saved dictation \(meta.id)")
        } catch {
            logger.log(.store, "Failed to save: \(error)")
        }
    }

    // MARK: - Soft Delete, Restore, Permanent Delete

    func softDelete(id: UUID) {
        guard let index = dictations.firstIndex(where: { $0.id == id }) else { return }
        var meta = dictations[index].meta
        meta.deletedAt = Date()
        dictations[index] = Dictation(meta: meta, transcript: dictations[index].transcript)
        writeMeta(meta)
        logger.log(.store, "Soft-deleted dictation \(id)")
    }

    func restore(id: UUID) {
        guard let index = dictations.firstIndex(where: { $0.id == id }) else { return }
        var meta = dictations[index].meta
        meta.deletedAt = nil
        dictations[index] = Dictation(meta: meta, transcript: dictations[index].transcript)
        writeMeta(meta)
        logger.log(.store, "Restored dictation \(id)")
    }

    func permanentlyDelete(id: UUID) {
        let dir = baseDir.appendingPathComponent(id.uuidString)
        try? FileManager.default.removeItem(at: dir)
        dictations.removeAll { $0.id == id }
        logger.log(.store, "Permanently deleted dictation \(id)")
    }

    func softDelete(ids: Set<UUID>) {
        for id in ids { softDelete(id: id) }
    }

    func permanentlyDelete(ids: Set<UUID>) {
        for id in ids { permanentlyDelete(id: id) }
    }

    private func writeMeta(_ meta: DictationMeta) {
        let dir = baseDir.appendingPathComponent(meta.id.uuidString)
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: dir.appendingPathComponent("meta.json"))
        }
    }

    // MARK: - In-App Dictation (create, update, finalize)

    func createBlank() -> UUID {
        let meta = DictationMeta()
        let dir = baseDir.appendingPathComponent(meta.id.uuidString)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let metaData = try JSONEncoder().encode(meta)
            try metaData.write(to: dir.appendingPathComponent("meta.json"))
            try "".write(to: dir.appendingPathComponent("dictation.md"), atomically: true, encoding: .utf8)
        } catch {
            logger.log(.store, "Failed to create blank: \(error)")
        }
        let dictation = Dictation(meta: meta, transcript: "")
        dictations.insert(dictation, at: 0)
        logger.log(.store, "Created blank dictation \(meta.id)")
        return meta.id
    }

    private var pendingWrite: DispatchWorkItem?

    func updateTranscript(id: UUID, transcript: String) {
        guard let index = dictations.firstIndex(where: { $0.id == id }) else { return }
        dictations[index] = Dictation(meta: dictations[index].meta, transcript: transcript)
        scheduleDiskWrite(id: id, transcript: transcript)
    }

    private func scheduleDiskWrite(id: UUID, transcript: String) {
        pendingWrite?.cancel()
        let base = baseDir
        let item = DispatchWorkItem {
            let dir = base.appendingPathComponent(id.uuidString)
            try? transcript.write(to: dir.appendingPathComponent("dictation.md"),
                                  atomically: true, encoding: .utf8)
        }
        pendingWrite = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func finalize(id: UUID, duration: TimeInterval, audioData: Data?) {
        // Flush any pending transcript write
        pendingWrite?.cancel()
        pendingWrite = nil
        if let index = dictations.firstIndex(where: { $0.id == id }) {
            let transcript = dictations[index].transcript
            let dir = baseDir.appendingPathComponent(id.uuidString)
            try? transcript.write(to: dir.appendingPathComponent("dictation.md"),
                                  atomically: true, encoding: .utf8)
        }
        guard let index = dictations.firstIndex(where: { $0.id == id }) else { return }
        var meta = dictations[index].meta
        meta.duration = duration
        meta.hasAudio = audioData != nil
        dictations[index] = Dictation(meta: meta, transcript: dictations[index].transcript)
        writeMeta(meta)
        if let audioData {
            let dir = baseDir.appendingPathComponent(id.uuidString)
            try? audioData.write(to: dir.appendingPathComponent("audio.wav"))
        }
        logger.log(.store, "Finalized dictation \(id)")
    }

    // MARK: - Auto-Purge

    private func purgeExpired() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        let expired = dictations.filter { ($0.deletedAt ?? .distantFuture) < cutoff }
        for note in expired {
            let dir = baseDir.appendingPathComponent(note.id.uuidString)
            try? FileManager.default.removeItem(at: dir)
            logger.log(.store, "Purged expired dictation \(note.id)")
        }
        dictations.removeAll { ($0.deletedAt ?? .distantFuture) < cutoff }
    }

    // MARK: - Audio

    func audioURL(for id: UUID) -> URL? {
        let url = baseDir.appendingPathComponent(id.uuidString).appendingPathComponent("audio.wav")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
