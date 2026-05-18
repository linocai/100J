import PersonalAffairsCore
import SwiftUI

struct PersonalNotesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: NoteStatus = .active
    @State private var type: NoteType?
    @State private var search = ""
    @State private var showingNewNote = false
    var onSelectNote: (Note) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                SurfaceView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        filterBar
                        if model.notes.isEmpty {
                            EmptyStateCardView(
                                title: "No ideas yet",
                                message: "Capture thoughts here before they become tasks.",
                                systemImage: "lightbulb"
                            )
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
                                ForEach(model.notes) { note in
                                    NoteCardView(
                                        note: note,
                                        onSelect: { onSelectNote(note) },
                                        onConvert: { convert(note) },
                                        onArchive: { archive(note) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .sheet(isPresented: $showingNewNote) {
            NoteFormView { draft in
                guard let space = model.personalSpace else { return }
                await model.run {
                    _ = try await model.noteRepository.create(
                        NoteCreateRequest(
                            spaceId: space.id,
                            title: draft.title.trimmedOrNil,
                            body: draft.body,
                            type: draft.type
                        )
                    )
                    model.notes = try await model.noteRepository.list(status: status, type: type, search: search.trimmedOrNil)
                }
            }
        }
        .task {
            await model.reloadNotes(status: status, type: type, search: search.trimmedOrNil)
        }
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "Personal",
            title: "Ideas / Notes",
            subtitle: "Notes are thoughts, not tasks. Convert only when they become work.",
            systemImage: "note.text"
        ) {
            Button {
                showingNewNote = true
            } label: {
                Label("New Idea", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var filterBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Picker("Status", selection: $status) {
                ForEach(NoteStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .onChange(of: status) { newValue in
                Task { await model.reloadNotes(status: newValue, type: type, search: search.trimmedOrNil) }
            }

            Picker("Type", selection: $type) {
                Text("All").tag(Optional<NoteType>.none)
                ForEach(NoteType.allCases) { type in
                    Text(type.label).tag(Optional(type))
                }
            }
            .frame(width: 120)
            .onChange(of: type) { newValue in
                Task { await model.reloadNotes(status: status, type: newValue, search: search.trimmedOrNil) }
            }

            TextField("Search", text: $search)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await model.reloadNotes(status: status, type: type, search: search.trimmedOrNil) }
                }
            Spacer()
            PillView(text: "Personal notes only", style: .personal)
        }
    }

    private func archive(_ note: Note) {
        Task {
            await model.run {
                _ = try await model.noteRepository.archive(id: note.id)
                model.notes = try await model.noteRepository.list(status: status, type: type, search: search.trimmedOrNil)
            }
        }
    }

    private func convert(_ note: Note) {
        Task {
            await model.run {
                let title = note.title?.trimmedOrNil ?? String(note.body.prefix(48))
                _ = try await model.noteRepository.convertToTask(
                    noteId: note.id,
                    request: ConvertNoteToTaskRequest(title: title, priority: .medium)
                )
                try await model.loadAllData()
            }
        }
    }
}

private struct NoteRow: View {
    let note: Note
    let archive: () -> Void
    let convert: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: note.type == .idea ? "lightbulb" : "doc.text")
                .foregroundStyle(note.type == .idea ? .yellow : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(note.title?.trimmedOrNil ?? "Untitled")
                    .font(.headline)
                Text(note.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                HStack {
                    BadgeText(text: note.type.label)
                    BadgeText(text: note.status.label)
                    if note.linkedTaskId != nil {
                        BadgeText(text: "Linked Task", color: .green)
                    }
                    if note.source == "agent" {
                        BadgeText(text: "Agent", color: .indigo)
                    }
                }
            }
            Spacer()
            Button(action: convert) {
                Image(systemName: "arrow.triangle.branch")
            }
            .buttonStyle(.borderless)
            .help("Convert to Task")
            Button(action: archive) {
                Image(systemName: "archivebox")
            }
            .buttonStyle(.borderless)
            .help("Archive")
        }
        .padding(.vertical, 6)
    }
}

struct NoteDraft {
    var title = ""
    var body = ""
    var type: NoteType = .idea
}

private struct NoteFormView: View {
    let save: (NoteDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = NoteDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "New Personal Note", subtitle: "Capture ideas and memos before they become tasks.")
            Form {
                TextField("Title", text: $draft.title)
                Picker("Type", selection: $draft.type) {
                    ForEach(NoteType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                TextField("Body", text: $draft.body, axis: .vertical)
                    .lineLimit(6...10)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    Task {
                        await save(draft)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 560)
    }
}
