import SwiftUI

@main
struct OpenDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("OpenDictation", id: "main") {
            RootView(store: appDelegate.dictationController.store)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .textEditing) {
                Button("All Notes") {
                    NotificationCenter.default.post(name: .showAllNotes, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Search") {
                    NotificationCenter.default.post(name: .searchNotes, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Recent") {
                    NotificationCenter.default.post(name: .showRecent, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

private struct RootView: View {
    let store: DictationStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var settings = AppSettings.shared

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainWindowView(store: store)
                    .frame(minWidth: 600, minHeight: 400)
            } else {
                OnboardingView()
            }
        }
        .tint(settings.accentColor.color)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = DiagnosticsLogger.shared
    let menuBar = MenuBarManager()
    let hotkeyManager = HotkeyManager()
    let dictationController = DictationController()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        logger.log(.app, "OpenDictation launched — v\(version) (\(build))")

        dictationController.setup()

        menuBar.setup()
        menuBar.onOpenWindow = {
            NSApp.activate()
            if let window = NSApp.windows.first(where: { $0.title == "OpenDictation" }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        
        menuBar.onToggleDictation = { [weak self] in
            self?.dictationController.toggle()
        }

        hotkeyManager.onToggle = { [weak self] in
            self?.dictationController.toggle()
        }
        let settings = AppSettings.shared
        hotkeyManager.register(keyCode: UInt32(settings.hotkeyKeyCode),
                               modifiers: UInt32(settings.hotkeyModifiers))

        NotificationCenter.default.addObserver(forName: .hotkeyChanged, object: nil, queue: .main) { [weak self] _ in
            self?.hotkeyManager.reregister()
        }

        NotificationCenter.default.addObserver(forName: .hotkeyDisable, object: nil, queue: .main) { [weak self] _ in
            self?.hotkeyManager.unregister()
        }

        NotificationCenter.default.addObserver(forName: .hotkeyEnable, object: nil, queue: .main) { [weak self] _ in
            self?.hotkeyManager.reregister()
        }

        dictationController.onSelectNote = { id in
            NotificationCenter.default.post(name: .selectNote, object: id)
        }

        NotificationCenter.default.addObserver(forName: .startDictation, object: nil, queue: .main) { [weak self] _ in
            self?.dictationController.toggle()
        }

        logger.log(.app, "Setup complete")
    }
}

extension Notification.Name {
    static let startDictation = Notification.Name("opendictation.startDictation")
    static let searchNotes = Notification.Name("opendictation.searchNotes")
    static let showAllNotes = Notification.Name("opendictation.showAllNotes")
    static let showRecent = Notification.Name("opendictation.showRecent")
    static let selectNote = Notification.Name("opendictation.selectNote")
    static let hotkeyChanged = Notification.Name("opendictation.hotkeyChanged")
    static let hotkeyDisable = Notification.Name("opendictation.hotkeyDisable")
    static let hotkeyEnable = Notification.Name("opendictation.hotkeyEnable")
}
