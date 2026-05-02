import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    @State private var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var monitor: Any?

    private var isDefault: Bool {
        settings.hotkeyKeyCode == kVK_Space && settings.hotkeyModifiers == optionKey
    }

    var body: some View {
        HStack {
            Text("Dictation Hotkey")
            Spacer()
            Button {
                startRecording()
            } label: {
                Text(isRecording ? "Press a key combo..." : settings.hotkeyDisplayString)
                    .frame(minWidth: 120)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)

            if !isDefault {
                Button("Reset") {
                    settings.hotkeyKeyCode = kVK_Space
                    settings.hotkeyModifiers = optionKey
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = !modifiers.intersection([.command, .option, .control, .shift]).isEmpty

            guard hasModifier else { return nil }

            let carbonMods = HotkeyDisplayHelper.carbonModifiers(from: modifiers)
            settings.hotkeyKeyCode = Int(event.keyCode)
            settings.hotkeyModifiers = Int(carbonMods)

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
