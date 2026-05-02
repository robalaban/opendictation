import SwiftUI
import AppKit

struct DictationDetailView: View {
    let dictation: Dictation
    let audioURL: URL?
    var onDelete: (() -> Void)?
    var onRestore: (() -> Void)?
    var onPermanentDelete: (() -> Void)?

    @State private var playbackState: PlaybackState = .stopped
    @State private var sound: NSSound?
    @State private var soundDelegate: SoundFinishedDelegate?
    @State private var showDeleteConfirmation = false

    private enum PlaybackState {
        case stopped, playing, paused
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 8)

            HStack(spacing: 6) {
                Text(dictation.date, style: .date)
                Text(dictation.date, style: .time)
                Text("\u{00B7}")
                Text(formatDuration(dictation.duration))
                Text("\u{00B7}")
                Text("\(dictation.transcript.count) chars")
                Spacer()
                if !dictation.isDeleted {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(dictation.transcript, forType: .string)
                    }
                    if audioURL != nil {
                        Button {
                            togglePlayback()
                        } label: {
                            Label(playbackButtonLabel, systemImage: playbackButtonIcon)
                        }
                    }
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Image(systemName: "trash")
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 24)

            ScrollView {
                Text(dictation.transcript)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .foregroundStyle(dictation.isDeleted ? .secondary : .primary)
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .allowsHitTesting(!dictation.isDeleted)
            }

            if dictation.isDeleted {
                trashActions
            }
        }
        .onChange(of: dictation.id) {
            stopPlayback()
        }
        .alert("Delete Permanently?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onPermanentDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This dictation will be permanently deleted. This action cannot be undone.")
        }
    }

    private var trashActions: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                Text("In Trash")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restore") {
                    onRestore?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                Button("Delete Permanently", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .controlSize(.regular)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }

    private var playbackButtonLabel: String {
        switch playbackState {
        case .stopped: return "Play"
        case .playing: return "Stop"
        case .paused: return "Resume"
        }
    }

    private var playbackButtonIcon: String {
        switch playbackState {
        case .stopped: return "play.fill"
        case .playing: return "stop.fill"
        case .paused: return "play.fill"
        }
    }

    private func togglePlayback() {
        switch playbackState {
        case .stopped:
            guard let url = audioURL else { return }
            let newSound = NSSound(contentsOf: url, byReference: true)
            let delegate = SoundFinishedDelegate { [self] in
                self.playbackState = .stopped
                self.sound = nil
                self.soundDelegate = nil
            }
            newSound?.delegate = delegate
            self.soundDelegate = delegate
            self.sound = newSound
            newSound?.play()
            playbackState = .playing
        case .playing:
            sound?.pause()
            playbackState = .paused
        case .paused:
            sound?.resume()
            playbackState = .playing
        }
    }

    private func stopPlayback() {
        sound?.stop()
        sound = nil
        soundDelegate = nil
        playbackState = .stopped
    }
}

private final class SoundFinishedDelegate: NSObject, NSSoundDelegate {
    let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func sound(_ sound: NSSound, didFinishPlaying finished: Bool) {
        DispatchQueue.main.async { self.onFinish() }
    }
}
