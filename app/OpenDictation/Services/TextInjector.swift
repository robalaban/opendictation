import Cocoa

final class TextInjector {
    private let logger = DiagnosticsLogger.shared

    struct Target {
        let pid: pid_t
        let element: AXUIElement
        let appName: String
    }

    func captureTarget() -> Target? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            logger.log(.inject, "No frontmost application")
            return nil
        }
        let pid = frontApp.processIdentifier
        let appName = frontApp.localizedName ?? "Unknown"
        let appElement = AXUIElementCreateApplication(pid)

        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement,
                                                    kAXFocusedUIElementAttribute as CFString,
                                                    &focusedValue)
        guard result == .success, let focused = focusedValue else {
            logger.log(.inject, "Cannot get focused element in \(appName)")
            return Target(pid: pid, element: appElement, appName: appName)
        }

        // CFTypeRef → AXUIElement cast always succeeds for CoreFoundation types
        let element = focused as! AXUIElement
        logger.log(.inject, "Captured target: \(appName) (PID \(pid))")
        return Target(pid: pid, element: element, appName: appName)
    }

    func insert(text: String, into target: Target) {
        // Strategy 1: Set selected text attribute
        let result1 = AXUIElementSetAttributeValue(target.element,
                                                     kAXSelectedTextAttribute as CFString,
                                                     text as CFTypeRef)
        if result1 == .success {
            logger.log(.inject, "Injected via kAXSelectedTextAttribute into \(target.appName)")
            return
        }

        // Strategy 2: Read value + range, splice
        var valueRef: CFTypeRef?
        var rangeRef: CFTypeRef?
        let hasValue = AXUIElementCopyAttributeValue(target.element,
                                                      kAXValueAttribute as CFString,
                                                      &valueRef)
        let hasRange = AXUIElementCopyAttributeValue(target.element,
                                                      kAXSelectedTextRangeAttribute as CFString,
                                                      &rangeRef)
        if hasValue == .success, hasRange == .success,
           let currentValue = valueRef as? String,
           let rangeValue = rangeRef {
            var range = CFRange()
            if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) {
                let startIndex = currentValue.index(currentValue.startIndex, offsetBy: range.location,
                                                     limitedBy: currentValue.endIndex) ?? currentValue.endIndex
                let endIndex = currentValue.index(startIndex, offsetBy: range.length,
                                                   limitedBy: currentValue.endIndex) ?? currentValue.endIndex
                var newValue = currentValue
                newValue.replaceSubrange(startIndex..<endIndex, with: text)
                let result2 = AXUIElementSetAttributeValue(target.element,
                                                            kAXValueAttribute as CFString,
                                                            newValue as CFTypeRef)
                if result2 == .success {
                    logger.log(.inject, "Injected via value splice into \(target.appName)")
                    return
                }
            }
        }

        // Strategy 3: Clipboard paste
        pasteViaClipboard(text: text, pid: target.pid, appName: target.appName)
    }

    func typeLive(text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        let chars = Array(text.utf16)
        guard !chars.isEmpty else { return }

        let chunkSize = 20
        for start in stride(from: 0, to: chars.count, by: chunkSize) {
            let end = min(start + chunkSize, chars.count)
            var chunk = Array(chars[start..<end])

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: false)

            keyDown?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyUp?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private func pasteViaClipboard(text: String, pid: pid_t, appName: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        logger.log(.inject, "Injected via clipboard paste into \(appName)")

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
