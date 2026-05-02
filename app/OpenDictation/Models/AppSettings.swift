import Carbon
import SwiftUI

enum AccentColorOption: String, CaseIterable {
    case blue, purple, pink, red, orange, yellow, green, graphite

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .graphite: return Color(.systemGray)
        }
    }

    var label: String { rawValue.capitalized }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var accentColor: AccentColorOption = AccentColorOption(rawValue: UserDefaults.standard.string(forKey: "accentColor") ?? "") ?? .blue {
        didSet { UserDefaults.standard.set(accentColor.rawValue, forKey: "accentColor") }
    }

    var modelDirectory: String = UserDefaults.standard.string(forKey: "modelDirectory") ?? "" {
        didSet { UserDefaults.standard.set(modelDirectory, forKey: "modelDirectory") }
    }

    var saveAudioRecordings: Bool = UserDefaults.standard.object(forKey: "saveAudioRecordings") as? Bool ?? true {
        didSet { UserDefaults.standard.set(saveAudioRecordings, forKey: "saveAudioRecordings") }
    }

    var launchAtLogin: Bool = UserDefaults.standard.bool(forKey: "launchAtLogin") {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    var hotkeyKeyCode: Int = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int ?? kVK_Space {
        didSet {
            UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    var hotkeyModifiers: Int = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int ?? optionKey {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    var hotkeyDisplayString: String {
        HotkeyDisplayHelper.displayString(keyCode: UInt32(hotkeyKeyCode), modifiers: UInt32(hotkeyModifiers))
    }

    private init() {}
}
