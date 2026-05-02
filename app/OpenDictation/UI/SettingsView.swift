import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.shared
    @State private var accessibilityGranted = PermissionsManager.shared.isAccessibilityGranted
    @State private var microphoneGranted = PermissionsManager.shared.isMicrophoneGranted
    @State private var microphoneDenied = PermissionsManager.shared.isMicrophoneDenied

    var body: some View {
        Form {
            Section("Voxtral Model") {
                HStack {
                    if settings.modelDirectory.isEmpty {
                        Text("No model directory selected")
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: modelPathIssue == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(modelPathIssue == nil ? .green : .red)
                        Text(settings.modelDirectory)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .help(settings.modelDirectory)
                    }
                    Spacer()
                    Button("Browse...") { browseModelDirectory() }
                }
                if let issue = modelPathIssue, !settings.modelDirectory.isEmpty {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Appearance") {
                HStack(spacing: 8) {
                    ForEach(AccentColorOption.allCases, id: \.self) { option in
                        Button {
                            settings.accentColor = option
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 24, height: 24)
                                if settings.accentColor == option {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(option.label)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Hotkey") {
                HotkeyRecorderView()
            }

            Section("Recording") {
                Toggle("Save audio recordings", isOn: Binding(
                    get: { settings.saveAudioRecordings },
                    set: { settings.saveAudioRecordings = $0 }
                ))
            }

            Section("Permissions") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))

                HStack {
                    Text("Accessibility")
                    Spacer()
                    if accessibilityGranted {
                        Text("Granted")
                            .foregroundStyle(.green)
                    } else {
                        Text("Not Granted")
                            .foregroundStyle(.red)
                        Button("Open Settings") {
                            PermissionsManager.shared.openAccessibilitySettings()
                        }
                    }
                }

                HStack {
                    Text("Microphone")
                    Spacer()
                    if microphoneGranted {
                        Text("Granted")
                            .foregroundStyle(.green)
                    } else if microphoneDenied {
                        Text("Denied")
                            .foregroundStyle(.red)
                        Button("Open Settings") {
                            PermissionsManager.shared.openMicrophoneSettings()
                        }
                    } else {
                        Text("Not Requested")
                            .foregroundStyle(.orange)
                        Button("Request") {
                            PermissionsManager.shared.requestMicrophone()
                        }
                    }
                }
            }

            Section("Diagnostics") {
                Button("Open Log File") {
                    NSWorkspace.shared.open(DiagnosticsLogger.shared.logFilePath)
                }
            }

            Section {
                Button("Re-run Setup Assistant") {
                    AppSettings.shared.hasCompletedOnboarding = false
                    dismiss()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            accessibilityGranted = PermissionsManager.shared.isAccessibilityGranted
            microphoneGranted = PermissionsManager.shared.isMicrophoneGranted
            microphoneDenied = PermissionsManager.shared.isMicrophoneDenied
            NotificationCenter.default.post(name: .hotkeyDisable, object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .hotkeyEnable, object: nil)
        }
    }

    private var modelPathIssue: String? {
        let path = settings.modelDirectory
        if path.isEmpty { return "Model directory is not set" }
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return "Directory does not exist"
        }
        if !isDir.boolValue { return "Path is not a directory" }
        let model = (path as NSString).appendingPathComponent("consolidated.safetensors")
        if !FileManager.default.fileExists(atPath: model) {
            return "consolidated.safetensors not found in directory"
        }
        return nil
    }

    private func browseModelDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the folder containing consolidated.safetensors"
        if panel.runModal() == .OK, let url = panel.url {
            settings.modelDirectory = url.path
        }
    }
}
