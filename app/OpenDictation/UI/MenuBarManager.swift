import AppKit
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    var onOpenWindow: (() -> Void)?
    var onToggleDictation: (() -> Void)?

    func setup() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.size = NSSize(width: 18, height: 18)
            icon?.isTemplate = true
            button.image = icon
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open OpenDictation", action: #selector(openWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func openWindow() {
        onOpenWindow?()
    }

    @objc private func toggleDictation() {
        onToggleDictation?()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
