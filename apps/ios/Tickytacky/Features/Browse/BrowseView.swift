import SwiftUI

struct BrowseView: View {
    @Environment(\.appDatabase) private var database
    private let theme = Theme.current

    var embedsNavigationStack: Bool = true

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
        ZStack {
            theme.canvas.ignoresSafeArea()
            content
        }
        .navigationTitle("Browse")
        .toolbar {
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
            ListEditorSheet(mode: .create) { reload() }
        }
        .sheet(isPresented: $showCreateTag) {
            TagEditorSheet(mode: .create) { _ in reload() }
        }
        .task { reload() }
        .onAppear { reload() }
        .onChange(of: showCreateList) { _, open in
            if !open { reload() }
        }
        .onChange(of: showCreateTag) { _, open in
            if !open { reload() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if summaries.isEmpty && tagSummaries.isEmpty {
            EmptyStateView(
                title: "Nothing to browse yet",
                message: "Create a list or tag to organize tasks."
            )
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List {
                if !summaries.isEmpty {
                    Section {
                        ForEach(summaries) { summary in
                            NavigationLink {
                                ListDetailView(listId: summary.list.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: summary.list.isInbox ? "tray.fill" : "folder")
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
                    }
                }

                Section {
                    if tagSummaries.isEmpty {
                        Text("No tags yet")
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
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { reload() }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(theme.inkMuted)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }

    private func reload() {
        summaries = (try? database.lists.fetchSummaries()) ?? []
        tagSummaries = (try? database.tags.fetchSummaries()) ?? []
    }
}
