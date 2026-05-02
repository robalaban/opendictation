import Carbon
import AppKit

enum HotkeyDisplayHelper {

    // MARK: - Modifier Conversion

    static func carbonModifiers(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if cocoa.contains(.control) { carbon |= UInt32(controlKey) }
        if cocoa.contains(.option)  { carbon |= UInt32(optionKey) }
        if cocoa.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if cocoa.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    static func cocoaModifiers(from carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbon & UInt32(optionKey) != 0  { flags.insert(.option) }
        if carbon & UInt32(shiftKey) != 0   { flags.insert(.shift) }
        if carbon & UInt32(cmdKey) != 0     { flags.insert(.command) }
        return flags
    }

    // MARK: - Display String

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        let cocoa = cocoaModifiers(from: modifiers)
        var parts: [String] = []
        if cocoa.contains(.control) { parts.append("\u{2303}") }
        if cocoa.contains(.option)  { parts.append("\u{2325}") }
        if cocoa.contains(.shift)   { parts.append("\u{21E7}") }
        if cocoa.contains(.command) { parts.append("\u{2318}") }
        parts.append(keyName(for: keyCode))
        return parts.joined()
    }

    // MARK: - Key Name

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space:       return "Space"
        case kVK_Return:      return "Return"
        case kVK_Tab:         return "Tab"
        case kVK_Delete:      return "Delete"
        case kVK_ForwardDelete: return "Fwd Del"
        case kVK_Escape:      return "Esc"
        case kVK_Home:        return "Home"
        case kVK_End:         return "End"
        case kVK_PageUp:      return "Page Up"
        case kVK_PageDown:    return "Page Down"
        case kVK_LeftArrow:   return "\u{2190}"
        case kVK_RightArrow:  return "\u{2192}"
        case kVK_UpArrow:     return "\u{2191}"
        case kVK_DownArrow:   return "\u{2193}"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default:
            return ucKeyTranslateName(for: keyCode)
        }
    }

    private static func ucKeyTranslateName(for keyCode: UInt32) -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "Key\(keyCode)"
        }
        let layoutData = unsafeBitCast(layoutPtr, to: CFData.self) as Data
        return layoutData.withUnsafeBytes { rawBuf -> String in
            guard let basePtr = rawBuf.baseAddress else { return "Key\(keyCode)" }
            let layoutPtr = basePtr.assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeyState: UInt32 = 0
            var length: Int = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return "Key\(keyCode)" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}
