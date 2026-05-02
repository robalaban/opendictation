import Foundation
import os

nonisolated final class DiagnosticsLogger: @unchecked Sendable {
    enum Category: String, Sendable {
        case hotkey = "HOTKEY"
        case audio = "AUDIO"
        case voxtral = "VOXTRAL"
        case inject = "INJECT"
        case overlay = "OVERLAY"
        case store = "STORE"
        case app = "APP"
    }

    static let shared = DiagnosticsLogger()

    private let logDir: URL
    private let logFile: URL
    private let queue: DispatchQueue
    private let osLog: os.Logger
    private let maxFileSize: UInt64 = 5 * 1024 * 1024 // 5MB
    private var fileHandle: FileHandle?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDir = appSupport.appendingPathComponent("OpenDictation/Logs")
        logFile = logDir.appendingPathComponent("OpenDictation.log")
        queue = DispatchQueue(label: "com.opendictation.logger")
        osLog = os.Logger(subsystem: "io.calysis.opendictation", category: "app")

        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
    }

    func log(_ category: Category, _ message: String) {
        let timestamp = Self.dateFormatter.string(from: Date())
        let line = "\(timestamp) [\(category.rawValue)] \(message)\n"

        osLog.log("[\(category.rawValue)] \(message)")

        queue.async { [self] in
            rotateIfNeeded()
            if let data = line.data(using: .utf8) {
                ensureFileHandle()
                fileHandle?.write(data)
            }
        }
    }

    private func ensureFileHandle() {
        if fileHandle == nil {
            if !FileManager.default.fileExists(atPath: logFile.path) {
                FileManager.default.createFile(atPath: logFile.path, contents: nil)
            }
            fileHandle = try? FileHandle(forWritingTo: logFile)
            fileHandle?.seekToEndOfFile()
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let size = attrs[.size] as? UInt64,
              size > maxFileSize else { return }
        let backup = logDir.appendingPathComponent("OpenDictation.old.log")
        try? fileHandle?.close()
        fileHandle = nil
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: logFile, to: backup)
    }

    var logFilePath: URL { logFile }
}
