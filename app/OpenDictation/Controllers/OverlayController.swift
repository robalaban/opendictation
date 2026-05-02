import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<OverlayView>?
    private(set) var state: OverlayState = .hidden {
        didSet {
            // Skip logging for amplitude updates — too noisy at 60 FPS
            switch state {
            case .listening:
                break
            default:
                DiagnosticsLogger.shared.log(.overlay, "State: \(state)")
            }
            hostingView?.rootView = OverlayView(state: state)
            if state.isVisible && panel?.isVisible == false {
                showPanel()
            } else if !state.isVisible {
                hidePanel()
            }
        }
    }

    func setup() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        let view = OverlayView(state: .hidden)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hostingView)

        self.panel = panel
        self.hostingView = hostingView
        positionBelowNotch()
    }

    private func positionBelowNotch() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 220
        let panelHeight: CGFloat = 120
        let x = screen.frame.midX - panelWidth / 2
        let y = visibleFrame.maxY - panelHeight - 8
        panel?.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func showPanel() {
        positionBelowNotch()
        panel?.orderFront(nil)
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    func showLoading() { state = .loading }
    func showListening(amplitude: Float) { state = .listening(amplitude: amplitude) }
    func showTranscribing(partialText: String = "") { state = .transcribing(partialText: partialText) }

    func showSuccess() {
        state = .success
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            state = .hidden
        }
    }

    func showError(message: String) {
        state = .error(message: message)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if case .error = state { state = .hidden }
        }
    }

    func hide() { state = .hidden }
}
