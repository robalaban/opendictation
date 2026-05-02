import Carbon

@MainActor
final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    fileprivate static var isKeyDown = false
    fileprivate static var handlersInstalled = false
    var onToggle: (() -> Void)?

    fileprivate static var instance: HotkeyManager?

    func register(keyCode: UInt32, modifiers: UInt32) {
        HotkeyManager.instance = self

        installEventHandlers()

        var hotkeyID = EventHotKeyID(signature: OSType(0x434D4456), // "CMDV"
                                      id: 1)
        RegisterEventHotKey(keyCode,
                           modifiers,
                           hotkeyID,
                           GetApplicationEventTarget(),
                           0,
                           &hotkeyRef)

        let display = HotkeyDisplayHelper.displayString(keyCode: keyCode, modifiers: modifiers)
        DiagnosticsLogger.shared.log(.hotkey, "Registered hotkey: \(display)")
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    func reregister() {
        unregister()
        let settings = AppSettings.shared
        register(keyCode: UInt32(settings.hotkeyKeyCode),
                 modifiers: UInt32(settings.hotkeyModifiers))
    }

    private func installEventHandlers() {
        guard !HotkeyManager.handlersInstalled else { return }
        HotkeyManager.handlersInstalled = true

        let pressHandler: EventHandlerUPP = { _, event, _ in
            guard !HotkeyManager.isKeyDown else { return noErr }
            HotkeyManager.isKeyDown = true
            Task { @MainActor in
                DiagnosticsLogger.shared.log(.hotkey, "Hotkey pressed")
                HotkeyManager.instance?.onToggle?()
            }
            return noErr
        }

        let releaseHandler: EventHandlerUPP = { _, event, _ in
            HotkeyManager.isKeyDown = false
            return noErr
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), pressHandler, 1, &eventType, nil, nil)

        var releaseType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                         eventKind: UInt32(kEventHotKeyReleased))
        InstallEventHandler(GetApplicationEventTarget(), releaseHandler, 1, &releaseType, nil, nil)
    }
}
