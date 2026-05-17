import PersonalAffairsCore
import SwiftUI

struct PersonalNotesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var status: NoteStatus = .active
    @State private var type: NoteType?
    @State private var search = ""
    @State private var showingNewNote = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.notes.isEmpty {
                EmptyStateView(title: "No personal notes", message: "Ideas and memos stay personal in v1.")
            } else {
                List(model.notes) { note in
                    NoteRow(
                        note: note,
                        archive: { archive(note) },
                        convert: { convert(note) }
                    )
                }
            }
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
        HStack(spacing: 16) {
            ToolbarTitle(title: "Personal Notes", subtitle: "Ideas and memos. Convert only when they become work.")
            Spacer()
            Picker("Status", selection: $status) {
                ForEach(NoteStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .frame(width: 130)
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
                .frame(width: 180)
                .onSubmit {
                    Task { await model.reloadNotes(status: status, type: type, search: search.trimmedOrNil) }
                }

            Button {
                showingNewNote = true
            } label: {
                Label("New Note", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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

private struct NoteDraft {
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
            Text("New Personal Note")
                .font(.title2.weight(.semibold))
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
        .padding()
        .frame(width: 480)
    }
}

