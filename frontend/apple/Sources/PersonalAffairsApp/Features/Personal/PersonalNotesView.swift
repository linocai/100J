import PersonalAffairsCore
import SwiftUI

struct PersonalNotesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var status: NoteStatus = .active
    @State private var type: NoteType?
    @State private var search = ""
    @State private var showingNewNote = false
    @FocusState private var isSearchFocused: Bool
    var selection: InspectorSelection? = nil
    var onSelectNote: (Note) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                statsStrip
                filterBar
                if model.notes.isEmpty {
                    EmptyStateCardView(
                        title: "暂无灵感",
                        message: "把突然想到的东西先放进这里，不需要马上变成待办。",
                        systemImage: "lightbulb"
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
                        ForEach(model.notes) { note in
                            NoteCardView(
                                note: note,
                                isSelected: selection == .note(note.id),
                                onSelect: { onSelectNote(note) },
                                onConvert: { convert(note) },
                                onArchive: { archive(note) }
                            )
                        }
                    }
                }
            }
            .padding(layout.pagePadding)
        }
        .sheet(isPresented: $showingNewNote) {
            NoteFormView { draft in
                await model.createNote(draft)
            }
        }
        .task {
            await model.reloadNotes(status: status, type: type, search: search.trimmedOrNil)
        }
        .background(searchShortcut)
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "个人",
            title: "灵感 / 备忘",
            subtitle: "备忘是想法，不是任务；只有确认要做时才转成待办。",
            systemImage: "note.text",
            accent: AppTheme.Colors.personalAccent
        ) {
            Button {
                showingNewNote = true
            } label: {
                Label("新建灵感", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filterBar: some View {
        GroupBox {
            ViewThatFits(in: .horizontal) {
                horizontalFilterBar
                verticalFilterBar
            }
        }
    }

    private var horizontalFilterBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            statusPicker
                .frame(width: 180)
            typePicker
                .frame(width: 120)

            TextField("搜索", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .frame(width: layout.narrowControlWidth)
                .onSubmit {
                    Task { await model.reloadNotes(status: status, type: type, search: search.trimmedOrNil) }
                }
            Spacer()
            PillView(text: "仅个人备忘", style: .personal)
        }
    }

    private var verticalFilterBar: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                statusPicker
                typePicker
            }
            TextField("搜索", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    Task { await model.reloadNotes(status: status, type: type, search: search.trimmedOrNil) }
                }
            PillView(text: "仅个人备忘", style: .personal)
        }
    }

    private var statusPicker: some View {
        Picker("状态", selection: $status) {
            ForEach(NoteStatus.allCases) { status in
                Text(status.label).tag(status)
            }
        }
        .pickerStyle(.segmented)
        .onValueChange(of: status) { newValue in
            Task { await model.reloadNotes(status: newValue, type: type, search: search.trimmedOrNil) }
        }
    }

    private var typePicker: some View {
        Picker("类型", selection: $type) {
            Text("全部").tag(Optional<NoteType>.none)
            ForEach(NoteType.allCases) { type in
                Text(type.label).tag(Optional(type))
            }
        }
        .onValueChange(of: type) { newValue in
            Task { await model.reloadNotes(status: status, type: newValue, search: search.trimmedOrNil) }
        }
    }

    private var statsStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AppTheme.Spacing.sm)], spacing: AppTheme.Spacing.sm) {
            MetricCardView(title: "Active ideas", value: "\(model.notes.filter { $0.status == .active && $0.type == .idea }.count)", caption: "灵感", style: .agent, systemImage: "lightbulb")
            MetricCardView(title: "Memos", value: "\(model.notes.filter { $0.type == .memo }.count)", caption: "备忘", style: .neutral, systemImage: "doc.text")
            MetricCardView(title: "Converted", value: "\(model.notes.filter { $0.linkedTaskId != nil }.count)", caption: "已转行动", style: .success, systemImage: "arrow.triangle.branch")
            MetricCardView(title: "Archived", value: "\(model.notes.filter { $0.status == .archived }.count)", caption: "已归档", style: .neutralSubtle, systemImage: "archivebox")
        }
    }

    private func archive(_ note: Note) {
        Task { await model.archiveNote(note) }
    }

    private func convert(_ note: Note) {
        Task { await model.convertNoteToTask(note) }
    }

    @ViewBuilder
    private var searchShortcut: some View {
        #if os(macOS)
        Button("聚焦搜索") {
            isSearchFocused = true
        }
        .keyboardShortcut("f", modifiers: .command)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
        #endif
    }
}

private struct NoteFormView: View {
    let save: (NoteDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = NoteDraft()

    var body: some View {
        EditorSheetView(
            title: "新建个人备忘",
            subtitle: "先记录灵感和备忘，等它变成行动再转为待办。",
            isActionDisabled: draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            cancel: { dismiss() },
            action: {
                Task {
                    await save(draft)
                    dismiss()
                }
            }
        ) {
            Form {
                TextField("标题", text: $draft.title)
                Picker("类型", selection: $draft.type) {
                    ForEach(NoteType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                TextField("正文", text: $draft.body, axis: .vertical)
                    .lineLimit(6...10)
            }
        }
    }
}
