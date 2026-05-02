import SwiftUI
import Combine

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var settings = AppSettings.shared
    @State private var micGranted = PermissionsManager.shared.isMicrophoneGranted
    @State private var axGranted = PermissionsManager.shared.isAccessibilityGranted
    private let totalSteps = 6
    private let permissionPoll = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    // MARK: - Validation

    private var canContinue: Bool {
        switch currentStep {
        case 1:
            return modelPathIssue == nil && !settings.modelDirectory.isEmpty
        default:
            return true
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

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Step numbers
            stepIndicator
                .padding(.top, 16)
                .padding(.bottom, 8)

            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: downloadModelStep
                case 2: microphoneStep
                case 3: accessibilityStep
                case 4: howItWorksStep
                case 5: doneStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            if currentStep != 0 && currentStep != 5 {
                navigationBar
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            NotificationCenter.default.post(name: .hotkeyDisable, object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .hotkeyEnable, object: nil)
        }
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("OpenDictation")
                .font(.largeTitle)
                .bold()

            Text("Voice to text, anywhere.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Get Started") {
                currentStep = 1
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { index in
                ZStack {
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : index < currentStep ? Color.green : Color.secondary.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(index <= currentStep ? .white : .secondary)
                }
                if index < totalSteps - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.green : Color.secondary.opacity(0.2))
                        .frame(height: 2)
                        .frame(maxWidth: 24)
                }
            }
        }
        .padding(.horizontal, 80)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button("Back") {
                if currentStep > 0 {
                    currentStep -= 1
                }
            }
            .buttonStyle(.borderless)

            Spacer()

            Button("Continue") {
                if currentStep < totalSteps - 1 {
                    currentStep += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Download Model Step

    private var downloadModelStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Download Model")
                .font(.title)
                .fontWeight(.bold)

            Text("OpenDictation uses Voxtral, a local speech-to-text model. Download the model weights from Hugging Face — no data ever leaves your Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Download from Hugging Face") {
                if let url = URL(string: "https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Directory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Button("Browse...") { browseDirectory() }
                }
                if let issue = modelPathIssue, !settings.modelDirectory.isEmpty {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 420)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Microphone Step

    private var microphoneStep: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(micGranted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: micGranted ? "checkmark.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(micGranted ? .green : .blue)
            }
            .animation(.easeInOut, value: micGranted)

            Text("Microphone Access")
                .font(.title)
                .fontWeight(.bold)

            Text("OpenDictation needs microphone access to hear your voice and transcribe it into text.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if micGranted {
                Text("Microphone access granted")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Button("Grant Access") {
                    PermissionsManager.shared.requestMicrophone()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip for now") {
                    withAnimation { currentStep += 1 }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(permissionPoll) { _ in
            micGranted = PermissionsManager.shared.isMicrophoneGranted
            axGranted = PermissionsManager.shared.isAccessibilityGranted
        }
    }

    // MARK: - Accessibility Step

    private var accessibilityStep: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(axGranted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: axGranted ? "checkmark.circle.fill" : "accessibility.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(axGranted ? .green : .blue)
            }
            .animation(.easeInOut, value: axGranted)

            Text("Accessibility Access")
                .font(.title)
                .fontWeight(.bold)

            Text("OpenDictation needs accessibility access to type transcribed text directly into any app you're using.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if axGranted {
                Text("Accessibility access granted")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Button("Grant Access") {
                    PermissionsManager.shared.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip for now") {
                    withAnimation { currentStep += 1 }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(permissionPoll) { _ in
            micGranted = PermissionsManager.shared.isMicrophoneGranted
            axGranted = PermissionsManager.shared.isAccessibilityGranted
        }
    }

    // MARK: - How It Works Step

    private var howItWorksStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "option",
                    title: "Press \(settings.hotkeyDisplayString)",
                    description: "Toggle recording on and off from anywhere on your Mac."
                )
                featureRow(
                    icon: "waveform",
                    title: "Speak naturally",
                    description: "Your voice is transcribed locally using Voxtral. Nothing leaves your Mac."
                )
                featureRow(
                    icon: "text.cursor",
                    title: "Text appears instantly",
                    description: "Transcribed text is typed directly into whatever app you're using."
                )
                featureRow(
                    icon: "clock.arrow.circlepath",
                    title: "History saved",
                    description: "All your dictations are stored and accessible from the main window."
                )
            }
            .frame(maxWidth: 400)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Done Step

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("You're all set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Press \(settings.hotkeyDisplayString) anytime to start dictating.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button("Start Using OpenDictation") {
                AppSettings.shared.hasCompletedOnboarding = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func browseDirectory() {
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
