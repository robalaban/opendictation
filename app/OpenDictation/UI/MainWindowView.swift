import SwiftUI

enum SidebarFilter {
    case all
    case recent
    case trash
}

struct MainWindowView: View {
    let store: DictationStore
    @State private var selectedDictations: Set<UUID> = []
    @State private var lastClickedID: UUID?
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var sidebarFilter: SidebarFilter = .all
    @State private var sidebarCollapsed = false
    @State private var confirmBatchDelete = false

    private var filteredDictations: [Dictation] {
        switch sidebarFilter {
        case .all: return store.activeNotes
        case .recent: return store.recentNotes
        case .trash: return store.trashedNotes
        }
    }

    /// The dictation to show in the detail pane: lastClickedID if it's in the selection, else first selected.
    private var detailDictation: Dictation? {
        let all = store.dictations
        if let id = lastClickedID, selectedDictations.contains(id),
           let d = all.first(where: { $0.id == id }) {
            return d
        }
        if let firstID = selectedDictations.first,
           let d = all.first(where: { $0.id == firstID }) {
            return d
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            // Floating Sidebar
            VStack(spacing: 0) {
                sidebarNavTop
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                Divider()
                    .padding(.top, 4)
                    .padding(.horizontal, 12)
                    .opacity(sidebarCollapsed ? 0 : 1)

                HistoryListView(
                    dictations: filteredDictations,
                    selection: $selectedDictations,
                    lastClicked: $lastClickedID,
                    isTrash: sidebarFilter == .trash,
                    onDelete: { ids in
                        selectAfterDelete(removing: ids)
                        store.softDelete(ids: ids)
                    },
                    onRestore: { id in
                        store.restore(id: id)
                        sidebarFilter = .all
                        selectedDictations = [id]
                        lastClickedID = id
                    },
                    onPermanentDelete: { ids in
                        selectAfterDelete(removing: ids)
                        store.permanentlyDelete(ids: ids)
                    }
                )
                .opacity(sidebarCollapsed ? 0 : 1)
                .allowsHitTesting(!sidebarCollapsed)

                Spacer(minLength: 0)

                Divider()
                    .padding(.horizontal, 12)
                    .opacity(sidebarCollapsed ? 0 : 1)

                sidebarNavBottom
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            .frame(width: sidebarCollapsed ? 52 : 250)
            .clipped()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.leading, 6)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .padding(.trailing, 2)

            // Detail
            Group {
                if let dictation = detailDictation {
                    DictationDetailView(
                        dictation: dictation,
                        audioURL: store.audioURL(for: dictation.id),
                        onDelete: {
                            let ids = selectedDictations
                            selectAfterDelete(removing: ids)
                            store.softDelete(ids: ids)
                        },
                        onRestore: {
                            store.restore(id: dictation.id)
                            sidebarFilter = .all
                            selectedDictations = [dictation.id]
                            lastClickedID = dictation.id
                        },
                        onPermanentDelete: {
                            let ids = selectedDictations
                            selectAfterDelete(removing: ids)
                            store.permanentlyDelete(ids: ids)
                        }
                    )
                } else {
                    if store.activeNotes.isEmpty && sidebarFilter != .trash {
                        Text("No dictations yet.\nPress \(Text("⌥ Space").bold()) to start your first one.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Select a dictation")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onKeyPress(.delete) {
            handleDeleteKey()
            return .handled
        }
        .onKeyPress(.init(Character(UnicodeScalar(127)))) { // Backspace (fn+Delete on Mac keyboards)
            handleDeleteKey()
            return .handled
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        sidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(sidebarCollapsed ? "Show sidebar" : "Hide sidebar")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(minWidth: 450, minHeight: 350)
        }
        .overlay {
            if showSearch {
                SearchOverlayView(
                    dictations: store.activeNotes,
                    onSelect: { id in
                        sidebarFilter = .all
                        selectedDictations = [id]
                        lastClickedID = id
                        showSearch = false
                    },
                    onDismiss: { showSearch = false }
                )
            }
        }
        .alert(
            selectedDictations.count > 1
                ? "Delete \(selectedDictations.count) Items Permanently?"
                : "Delete Permanently?",
            isPresented: $confirmBatchDelete
        ) {
            Button("Delete", role: .destructive) {
                let ids = selectedDictations
                selectAfterDelete(removing: ids)
                store.permanentlyDelete(ids: ids)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if selectedDictations.count > 1 {
                Text("These \(selectedDictations.count) dictations will be permanently deleted. This action cannot be undone.")
            } else {
                Text("This dictation will be permanently deleted. This action cannot be undone.")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchNotes)) { _ in
            showSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAllNotes)) { _ in
            sidebarFilter = .all
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRecent)) { _ in
            sidebarFilter = .recent
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectNote)) { notification in
            if let id = notification.object as? UUID {
                sidebarFilter = .all
                selectedDictations = [id]
                lastClickedID = id
            }
        }
    }

    // MARK: - Sidebar Navigation

    private var sidebarNavTop: some View {
        VStack(spacing: 2) {
            sidebarButton(label: "New Dictation", icon: "plus.circle.fill", shortcutKeys: ["\u{2325}", "Space"],
                          isPrimary: true) {
                NotificationCenter.default.post(name: .startDictation, object: nil)
            }
            sidebarButton(label: "Search", icon: "magnifyingglass", shortcutKeys: ["\u{2318}", "F"]) {
                showSearch = true
            }
            sidebarButton(label: "All Notes", icon: "doc.text", shortcutKeys: ["\u{2318}", "L"],
                          isActive: sidebarFilter == .all) {
                sidebarFilter = .all
                expandIfCollapsed()
            }
            sidebarButton(label: "Recent", icon: "clock", shortcutKeys: ["\u{2318}", "R"],
                          isActive: sidebarFilter == .recent) {
                sidebarFilter = .recent
                expandIfCollapsed()
            }
        }
    }

    private var sidebarNavBottom: some View {
        VStack(spacing: 2) {
            sidebarButton(label: "Trash", icon: "trash.fill",
                          badge: store.trashedNotes.count,
                          isActive: sidebarFilter == .trash) {
                sidebarFilter = .trash
                expandIfCollapsed()
            }
            sidebarButton(label: "Settings", icon: "gear") {
                showSettings.toggle()
            }
        }
    }

    private func sidebarButton(label: String, icon: String, shortcutKeys: [String]? = nil,
                                badge: Int? = nil, isActive: Bool = false,
                                isPrimary: Bool = false,
                                action: @escaping () -> Void) -> some View {
        SidebarButtonView(label: label, icon: icon, shortcutKeys: shortcutKeys,
                          badge: badge, isActive: isActive, isPrimary: isPrimary,
                          sidebarCollapsed: sidebarCollapsed,
                          action: action)
    }
}

private struct SidebarButtonView: View {
    let label: String
    let icon: String
    var shortcutKeys: [String]?
    var badge: Int?
    var isActive: Bool
    var isPrimary: Bool = false
    var sidebarCollapsed: Bool
    var action: () -> Void

    @State private var isHovered = false
    private var appAccent: Color { AppSettings.shared.accentColor.color }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .foregroundStyle(isPrimary ? appAccent : .primary)
                        .frame(width: 20)
                    if let badge, badge > 0 {
                        Circle()
                            .fill(Color(.windowBackgroundColor))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(badge)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 13, minHeight: 13)
                                    .background(appAccent)
                                    .clipShape(Circle())
                            )
                            .offset(x: 6, y: -6)
                            .opacity(sidebarCollapsed ? 1 : 0)
                            .animation(.easeInOut(duration: 0.3), value: sidebarCollapsed)
                    }
                }
                if !sidebarCollapsed {
                    Text(label)
                    Spacer()
                    if let badge, badge > 0 {
                        Text("\(badge)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .cornerRadius(4)
                    }
                    if let keys = shortcutKeys {
                        Text(keys.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(
                        isActive && !sidebarCollapsed ? 0.1 : (isHovered ? 0.06 : 0)
                    ))
                    .transaction { $0.animation = nil }
            )
            .transaction { $0.animation = nil }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { hovering in isHovered = hovering }
        .help(sidebarCollapsed ? label : "")
    }
}

extension MainWindowView {
    // MARK: - Helpers

    private func expandIfCollapsed() {
        if sidebarCollapsed {
            withAnimation(.easeInOut(duration: 0.25)) {
                sidebarCollapsed = false
            }
        }
    }

    private func selectAfterDelete(removing ids: Set<UUID>) {
        let list = filteredDictations
        let removingIndices = list.enumerated()
            .filter { ids.contains($0.element.id) }
            .map(\.offset)
        guard let lowestIndex = removingIndices.min() else { return }

        let remaining = list.filter { !ids.contains($0.id) }
        if remaining.isEmpty {
            selectedDictations = []
            lastClickedID = nil
            return
        }

        // Select the item at the same position (or the last one if we deleted from the end)
        let newIndex = min(lowestIndex, remaining.count - 1)
        let newID = remaining[newIndex].id
        selectedDictations = [newID]
        lastClickedID = newID
    }

    private func handleDeleteKey() {
        guard !selectedDictations.isEmpty else { return }
        if sidebarFilter == .trash {
            confirmBatchDelete = true
        } else {
            let ids = selectedDictations
            selectAfterDelete(removing: ids)
            store.softDelete(ids: ids)
        }
    }
}
