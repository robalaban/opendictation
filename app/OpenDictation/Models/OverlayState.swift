import Foundation

enum OverlayState: Equatable {
    case hidden
    case loading
    case listening(amplitude: Float)
    case transcribing(partialText: String)
    case success
    case error(message: String)

    var isVisible: Bool {
        self != .hidden
    }
}
