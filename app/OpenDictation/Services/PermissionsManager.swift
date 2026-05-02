import Cocoa
import AVFoundation

final class PermissionsManager {
    static let shared = PermissionsManager()

    var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    var isMicrophoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    var isMicrophoneDenied: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .denied
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        DiagnosticsLogger.shared.log(.app, "Accessibility permission requested")
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DiagnosticsLogger.shared.log(.app, "Microphone permission \(granted ? "granted" : "denied")")
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
