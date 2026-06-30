import SwiftUI

struct HistoryView: View {
    @Bindable var historyStore: HistoryStore
    let onSelect: (ClipItem) -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    let onSearchActiveChanged: (Bool) -> Void

    @State private var searchText = ""
    @State private var selectedID: UUID?
    @State private var hoveredID: UUID?
    @FocusState private var searchFocused: Bool

    private let popoverWidth: CGFloat = 340
    private let panelHeight: CGFloat = 420

    init(
        historyStore: HistoryStore,
        onSelect: @escaping (ClipItem) -> Void,
        onClose: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void = {},
        onSearchActiveChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.historyStore = historyStore
        self.onSelect = onSelect
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
        self.onSearchActiveChanged = onSearchActiveChanged
    }

    private var filteredItems: [ClipItem] {
        guard !searchText.isEmpty else { return historyStore.items }
        let query = searchText.lowercased()
        return historyStore.items.filter { item in
            let preview = item.previewText?.lowercased() ?? ""
            let source = item.source?.name.lowercased() ?? ""
            let kind = item.kind.rawValue.lowercased()
            return preview.contains(query) || source.contains(query) || kind.contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: popoverWidth, height: panelHeight, alignment: .topLeading)
        .background(Color.clear)
        .onAppear {
            selectedID = filteredItems.first?.id
            searchFocused = false
        }
        .onChange(of: filteredItems.map(\.id)) { _, ids in
            if let selectedID, ids.contains(selectedID) {
                return
            }
            self.selectedID = ids.first
        }
        .onChange(of: searchText) { _, _ in
            reportSearchActivity()
        }
        .onChange(of: searchFocused) { _, _ in
            reportSearchActivity()
        }
        .background {
            KeyHandlingView { event in
                handleKey(event)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search history", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityLabel("Search history")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if filteredItems.isEmpty {
            EmptyStateView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            ClipRowView(
                                item: item,
                                isSelected: selectedID == item.id,
                                isHovered: hoveredID == item.id,
                                onTap: {
                                    selectedID = item.id
                                    onSelect(item)
                                }
                            )
                            .id(item.id)
                            .onHover { isHovering in
                                if isHovering {
                                    hoveredID = item.id
                                } else if hoveredID == item.id {
                                    hoveredID = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: .infinity)
                .onChange(of: selectedID) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(historyStore.items.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(historyStore.items.count) clips in history")

            Spacer()

            Button("Clear All") {
                historyStore.clearAll()
                selectedID = nil
            }
            .disabled(historyStore.items.isEmpty)
            .accessibilityLabel("Clear all clips")

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Open settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 126:
            moveSelection(offset: -1)
            return true
        case 125:
            moveSelection(offset: 1)
            return true
        case 36:
            if let selectedID, let item = filteredItems.first(where: { $0.id == selectedID }) {
                onSelect(item)
            }
            return true
        case 51:
            if let selectedID, let item = filteredItems.first(where: { $0.id == selectedID }) {
                delete(item)
            }
            return true
        case 53:
            onClose()
            return true
        default:
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "f" {
                searchFocused = true
                return true
            }
            return false
        }
    }

    private func moveSelection(offset: Int) {
        let items = filteredItems
        guard !items.isEmpty else { return }
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else {
            self.selectedID = items.first?.id
            return
        }
        let nextIndex = min(max(index + offset, 0), items.count - 1)
        self.selectedID = items[nextIndex].id
    }

    private func delete(_ item: ClipItem) {
        historyStore.remove(id: item.id)
        if selectedID == item.id {
            selectedID = filteredItems.first?.id
        }
    }

    private func reportSearchActivity() {
        onSearchActiveChanged(searchFocused || !searchText.isEmpty)
    }
}

private struct KeyHandlingView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

private final class KeyCatcherView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }
}
