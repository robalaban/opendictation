import SwiftUI

struct SearchOverlayView: View {
    let dictations: [Dictation]
    let onSelect: (UUID) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var results: [Dictation] {
        guard !query.isEmpty else { return [] }
        return dictations.filter {
            $0.transcript.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search notes...", text: $query)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit {
                            if let first = results.first {
                                onSelect(first.id)
                            }
                        }
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                if !results.isEmpty {
                    Divider()
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(results) { dictation in
                                Button {
                                    onSelect(dictation.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(dictation.preview.isEmpty ? "New Note" : dictation.preview)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text(matchSnippet(in: dictation.transcript))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
            .frame(width: 400)
            .padding(.bottom, 100)
        }
        .onAppear { isFocused = true }
        .onExitCommand { onDismiss() }
    }

    private func matchSnippet(in text: String) -> String {
        guard let range = text.range(of: query, options: .caseInsensitive) else {
            return String(text.prefix(100))
        }
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
        let snippet = text[start..<end]
        return (start > text.startIndex ? "..." : "") + snippet + (end < text.endIndex ? "..." : "")
    }
}
