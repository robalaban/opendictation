import SwiftUI

struct HistoryListView: View {
    let dictations: [Dictation]
    @Binding var selection: Set<UUID>
    @Binding var lastClicked: UUID?
    let isTrash: Bool
    var onDelete: ((Set<UUID>) -> Void)?
    var onRestore: ((UUID) -> Void)?
    var onPermanentDelete: ((Set<UUID>) -> Void)?

    @State private var confirmDeleteIDs: Set<UUID> = []

    private var orderedIDs: [UUID] { dictations.map(\.id) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(dictations) { dictation in
                    NoteRowView(
                        dictation: dictation,
                        isSelected: selection.contains(dictation.id),
                        isTrash: isTrash,
                        actionCount: selection.contains(dictation.id) ? selection.count : 1,
                        onSelect: { handleSelect(id: dictation.id) },
                        onDelete: {
                            let ids = actionIDs(for: dictation.id)
                            onDelete?(ids)
                        },
                        onRestore: { onRestore?(dictation.id) },
                        onPermanentDelete: {
                            confirmDeleteIDs = actionIDs(for: dictation.id)
                        }
                    )
                }
            }
            .padding(.top, 4)
        }
        .alert(
            confirmDeleteIDs.count > 1
                ? "Delete \(confirmDeleteIDs.count) Items Permanently?"
                : "Delete Permanently?",
            isPresented: Binding(
                get: { !confirmDeleteIDs.isEmpty },
                set: { if !$0 { confirmDeleteIDs = [] } }
            )
        ) {
            Button("Delete", role: .destructive) {
                onPermanentDelete?(confirmDeleteIDs)
                confirmDeleteIDs = []
            }
            Button("Cancel", role: .cancel) {
                confirmDeleteIDs = []
            }
        } message: {
            if confirmDeleteIDs.count > 1 {
                Text("These \(confirmDeleteIDs.count) dictations will be permanently deleted. This action cannot be undone.")
            } else {
                Text("This dictation will be permanently deleted. This action cannot be undone.")
            }
        }
    }

    // MARK: - Selection Logic

    private func handleSelect(id: UUID) {
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []

        if modifiers.contains(.command) {
            // Cmd+Click: toggle individual item
            if selection.contains(id) {
                selection.remove(id)
            } else {
                selection.insert(id)
            }
            lastClicked = id
        } else if modifiers.contains(.shift), let anchor = lastClicked {
            // Shift+Click: range select from lastClicked to this item
            let ids = orderedIDs
            guard let anchorIndex = ids.firstIndex(of: anchor),
                  let clickIndex = ids.firstIndex(of: id) else {
                selection = [id]
                lastClicked = id
                return
            }
            let range = min(anchorIndex, clickIndex)...max(anchorIndex, clickIndex)
            selection = Set(ids[range])
            // lastClicked stays as anchor
        } else {
            // Plain click: select only this item
            selection = [id]
            lastClicked = id
        }
    }

    /// If the right-clicked item is in the selection, act on all selected; otherwise act on just that item.
    private func actionIDs(for id: UUID) -> Set<UUID> {
        if selection.contains(id) {
            return selection
        } else {
            selection = [id]
            lastClicked = id
            return [id]
        }
    }
}

private struct NoteRowView: View {
    let dictation: Dictation
    let isSelected: Bool
    let isTrash: Bool
    let actionCount: Int
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onRestore: () -> Void
    var onPermanentDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dictation.preview.isEmpty ? "New Note" : dictation.preview)
                    .font(.body)
                    .lineLimit(2)
                HStack {
                    Text(dictation.date, style: .date)
                    Text("\u{00B7}")
                    Text(formatDuration(dictation.duration))
                    if isTrash, let deletedAt = dictation.deletedAt {
                        let days = daysUntilExpiry(deletedAt: deletedAt)
                        if days <= 3 || isHovered || isSelected {
                            Spacer()
                            Text(daysRemaining(days: days))
                                .foregroundStyle(days <= 3 ? Color.orange : Color.accentColor)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primary.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering in isHovered = hovering }
        .contextMenu {
            if isTrash {
                Button(action: onRestore) {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                Button(role: .destructive, action: onPermanentDelete) {
                    Label(
                        actionCount > 1 ? "Delete \(actionCount) Items Permanently" : "Delete Permanently",
                        systemImage: "trash.slash"
                    )
                }
            } else {
                Button(role: .destructive, action: onDelete) {
                    Label(
                        actionCount > 1 ? "Move \(actionCount) Items to Trash" : "Move to Trash",
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        return "\(s / 60)m \(s % 60)s"
    }

    private func daysUntilExpiry(deletedAt: Date) -> Int {
        let calendar = Calendar.current
        let expiry = calendar.date(byAdding: .day, value: 15, to: deletedAt)!
        return calendar.dateComponents([.day], from: Date(), to: expiry).day ?? 0
    }

    private func daysRemaining(days: Int) -> String {
        if days <= 0 { return "Expiring" }
        return "\(days)d left"
    }
}
