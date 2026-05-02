import Foundation

struct DictationMeta: Codable, Identifiable {
    let id: UUID
    let date: Date
    var duration: TimeInterval
    var hasAudio: Bool
    var deletedAt: Date?

    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval = 0, hasAudio: Bool = false, deletedAt: Date? = nil) {
        self.id = id
        self.date = date
        self.duration = duration
        self.hasAudio = hasAudio
        self.deletedAt = deletedAt
    }
}
