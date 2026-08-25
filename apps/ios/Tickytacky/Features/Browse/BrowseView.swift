import SwiftUI

enum BrowsePane: String, CaseIterable, Identifiable {
    case today
    case lists

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "Day"
        case .lists: "Lists"
        }
    }
}

struct BrowseView: View {
    @Environment(\.appDatabase) private var database
    private let theme = Theme.current

    var embedsNavigationStack: Bool = true
    var initialPane: BrowsePane = .today

    @State private var pane: BrowsePane = .today
    @State private var summaries: [ListService.ListSummary] = []
    @State private var tagSummaries: [TagService.TagSummary] = []
    @State private var showCreateList = false
    @State private var showCreateTag = false

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack { root }
            } else {
                root
            }
        }
    }

    private var root: some View {
        VStack(spacing: 0) {
            Picker("Today", selection: $pane) {
                ForEach(BrowsePane.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(theme.canvas)

            Group {
                switch pane {
                case .today:
                    TodayView(embedsNavigationStack: false, showsNavigationTitle: false)
                case .lists:
                    listsRoot
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Today")
        .toolbar {
            if pane == .lists {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showCreateList = true
                        } label: {
                            Label("New List", systemImage: "folder.badge.plus")
                        }
                        Button {
                            showCreateTag = true
                        } label: {
                            Label("New Tag", systemImage: "tag")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add list or tag")
                }
            }
            ToolbarItem(placement: .navigation) {
                NavigationLink {
                    SearchView()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search")
            }
        }
        .sheet(isPresented: $showCreateList) {
            ListEditorSheet(mode: .create) { reloadLists() }
        }
        .sheet(isPresented: $showCreateTag) {
            TagEditorSheet(mode: .create) { _ in reloadLists() }
        }
        .task {
            pane = initialPane
            reloadLists()
        }
        .onAppear { reloadLists() }
        .onReceive(NotificationCenter.default.publisher(for: .tickytackySelectBrowsePane)) { note in
            if let raw = note.object as? String, let next = BrowsePane(rawValue: raw) {
                pane = next
            } else if let next = note.object as? BrowsePane {
                pane = next
            }
        }
        .onChange(of: showCreateList) { _, open in
            if !open { reloadLists() }
        }
        .onChange(of: showCreateTag) { _, open in
            if !open { reloadLists() }
        }
    }

    @ViewBuilder
    private var listsRoot: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            listsContent
        }
    }

    @ViewBuilder
    private var listsContent: some View {
        if summaries.isEmpty && tagSummaries.isEmpty {
            EmptyStateView(
                title: "Nothing to browse yet",
                message: "Prefer a few lists. Create tags for classes and projects."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List {
                Section {
                    if tagSummaries.isEmpty {
                        Text("No tags yet — add class or project tags (e.g. MATH101).")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                            .listRowBackground(theme.canvas)
                    } else {
                        ForEach(tagSummaries) { summary in
                            NavigationLink {
                                TagDetailView(tagId: summary.tag.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "tag")
                                        .foregroundStyle(theme.accentSecondary)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(summary.tag.name)
                                            .font(.body)
                                            .foregroundStyle(theme.ink)
                                        Text(summary.openTaskCount == 1
                                             ? "1 open task"
                                             : "\(summary.openTaskCount) open tasks")
                                            .font(.caption)
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .accessibilityLabel("\(summary.tag.name), \(summary.openTaskCount == 1 ? "1 open task" : "\(summary.openTaskCount) open tasks")")
                            .listRowBackground(theme.canvas)
                            .listRowSeparatorTint(theme.rule)
                        }
                    }
                } header: {
                    sectionHeader("Tags")
                } footer: {
                    Text("Use tags for classes and projects. Open Life and keep Group by tag on for soft subheadings.")
                        .foregroundStyle(theme.inkFaint)
                }

                if !summaries.isEmpty {
                    Section {
                        ForEach(summaries) { summary in
                            NavigationLink {
                                ListDetailView(listId: summary.list.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: groceryOrFolderIcon(summary.list))
                                        .foregroundStyle(theme.accent)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(summary.list.name)
                                            .font(.body)
                                            .foregroundStyle(theme.ink)
                                        Text(summary.openTaskCount == 1
                                             ? "1 open task"
                                             : "\(summary.openTaskCount) open tasks")
                                            .font(.caption)
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .accessibilityLabel("\(summary.list.name), \(summary.openTaskCount == 1 ? "1 open task" : "\(summary.openTaskCount) open tasks")")
                            .listRowBackground(theme.canvas)
                            .listRowSeparatorTint(theme.rule)
                        }
                    } header: {
                        sectionHeader("Lists")
                    } footer: {
                        Text("Prefer a few lists (Inbox, Life, Groceries). Avoid one list per class.")
                            .foregroundStyle(theme.inkFaint)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { reloadLists() }
        }
    }

    private func groceryOrFolderIcon(_ list: TaskListRecord) -> String {
        if list.isInbox { return "tray.fill" }
        if GroceryMode.isGroceryListName(list.name) { return "cart" }
        return "folder"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(theme.inkMuted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }

    private func reloadLists() {
        summaries = (try? database.lists.fetchSummaries()) ?? []
        tagSummaries = (try? database.tags.fetchSummaries()) ?? []
    }
}

extension Notification.Name {
    static let tickytackySelectBrowsePane = Notification.Name("tickytackySelectBrowsePane")
}
