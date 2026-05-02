import Foundation

struct Dictation: Identifiable {
    let meta: DictationMeta
    var transcript: String

    var id: UUID { meta.id }
    var date: Date { meta.date }
    var duration: TimeInterval { meta.duration }
    var hasAudio: Bool { meta.hasAudio }
    var deletedAt: Date? { meta.deletedAt }
    var isDeleted: Bool { meta.deletedAt != nil }

    var preview: String {
        let firstLine = transcript.split(separator: "\n").first.map(String.init) ?? transcript
        return String(firstLine.prefix(100))
    }
}
