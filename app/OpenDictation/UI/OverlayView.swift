import SwiftUI

struct OverlayView: View {
    let state: OverlayState

    var body: some View {
        ZStack {
            switch state {
            case .hidden:
                EmptyView()
            case .loading:
                LoadingOverlay()
            case .listening(let amplitude):
                ListeningOverlay(amplitude: amplitude)
            case .transcribing(let partialText):
                TranscribingOverlay(partialText: partialText)
            case .success:
                SuccessOverlay()
            case .error(let message):
                ErrorOverlay(message: message)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: state.isVisible)
    }
}

// MARK: - Shared Style

private let pillFont: Font = .system(size: 13, weight: .medium)
private let pillIconFont: Font = .system(size: 14, weight: .semibold)

// MARK: - Loading

private struct LoadingOverlay: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.dotted")
                .font(pillIconFont)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(rotation))
            Text("Loading")
                .font(pillFont)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Listening

private struct ListeningOverlay: View {
    let amplitude: Float

    private static let barWeights: [CGFloat] = [0.5, 1.0, 1.0, 0.5]
    private static let phaseOffsets: [Double] = [0.0, 0.5, 1.0, 1.5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 3.5
            let amp = CGFloat(max(0.08, min(1.0, amplitude)))

            HStack(spacing: 8) {
                HStack(spacing: 2.5) {
                    ForEach(0..<4, id: \.self) { i in
                        let wave = (sin(phase + Self.phaseOffsets[i]) + 1.0) / 2.0
                        let barHeight = 3.0 + Self.barWeights[i] * amp * 14.0 * (0.5 + 0.5 * wave)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.primary)
                            .frame(width: 3, height: barHeight)
                    }
                }
                .frame(width: 18, height: 18, alignment: .center)

                Text("Listening")
                    .font(pillFont)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular)
        }
    }
}

// MARK: - Transcribing

private struct TranscribingOverlay: View {
    let partialText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(pillIconFont)
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text("Processing")
                .font(pillFont)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular)
    }
}

// MARK: - Success

private struct SuccessOverlay: View {
    @State private var appear = false
    @State private var dismiss = false

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.primary)
            .padding(10)
            .glassEffect(.regular)
            .scaleEffect(appear ? 1.0 : 0.85)
            .opacity(dismiss ? 0 : 1)
            .onAppear {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    appear = true
                }
                withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                    dismiss = true
                }
            }
    }
}

// MARK: - Error

private struct ErrorOverlay: View {
    let message: String
    @State private var appear = false
    @State private var dismiss = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(pillIconFont)
                .foregroundStyle(.secondary)
            Text(message)
                .font(pillFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular)
        .scaleEffect(appear ? 1.0 : 0.85)
        .opacity(dismiss ? 0 : 1)
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(2.5)) {
                dismiss = true
            }
        }
    }
}

#Preview("All Overlay States") {
    VStack(spacing: 24) {
        OverlayView(state: .loading)
        OverlayView(state: .listening(amplitude: 0.5))
        OverlayView(state: .transcribing(partialText: "Hello world"))
        OverlayView(state: .success)
        OverlayView(state: .error(message: "Microphone unavailable"))
    }
    .padding(40)
    .frame(width: 400, height: 400)
    .background(.black.opacity(0.8))
}
