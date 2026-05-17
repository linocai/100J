#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter = "all"
    @State private var selectedProjectId: String?
    @State private var showingNewItem = false
    @State private var editingItem: CalendarItem?

    var body: some View {
        NavigationStack {
            List {
                IOSScreenHeader(title: "Calendar", subtitle: "A single agenda for Personal and Company fixed-time items.")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)

                Section {
                    Picker("Filter", selection: $filter) {
                        Text("All").tag("all")
                        Text("Personal").tag("personal")
                        Text("Company").tag("company")
                        Text("Project").tag("project")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: filter) { _ in Task { await reload() } }

                    if filter == "project" {
                        Picker("Project", selection: $selectedProjectId) {
                            Text("Choose").tag(Optional<String>.none)
                            ForEach(model.projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                        .onChange(of: selectedProjectId) { _ in Task { await reload() } }
                    }
                }

                Section("Agenda") {
                    if model.calendarItems.isEmpty {
                        IOSUnavailableView(title: "No Items", systemImage: "calendar", message: "Fixed dates and appointments will appear here.")
                    } else {
                        ForEach(model.calendarItems) { item in
                            IOSCalendarRow(
                                item: item,
                                space: spaceLabel(item.spaceId, spaces: model.spaces),
                                project: projectName(item.projectId, projects: model.projects)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingItem = item
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await delete(item) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    showingNewItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(item: $editingItem) { item in
                IOSCalendarItemForm(
                    title: "Edit Calendar Item",
                    projects: model.projects,
                    initialDraft: draft(from: item),
                    allowsOwnershipChange: false
                ) { draft in
                    await model.run {
                        _ = try await model.calendarRepository.update(
                            id: item.id,
                            request: CalendarItemUpdateRequest(
                                title: draft.title,
                                description: draft.description.trimmedOrNil,
                                type: draft.type,
                                allDay: draft.allDay,
                                startDate: draft.allDay ? draft.startDate.trimmedOrNil : nil,
                                startAt: draft.allDay ? nil : draft.startAt,
                                timezone: TimeZone.current.identifier,
                                recurrence: draft.recurrence,
                                projectId: draft.spaceType == .company ? draft.projectId : nil
                            )
                        )
                        await reload()
                    }
                }
            }
            .sheet(isPresented: $showingNewItem) {
                IOSCalendarItemForm(projects: model.projects) { draft in
                    let targetSpace = draft.spaceType == .personal ? model.personalSpace : model.companySpace
                    guard let space = targetSpace else { return }
                    await model.run {
                        _ = try await model.calendarRepository.create(
                            CalendarItemCreateRequest(
                                spaceId: space.id,
                                title: draft.title,
                                description: draft.description.trimmedOrNil,
                                type: draft.type,
                                allDay: draft.allDay,
                                startDate: draft.allDay ? draft.startDate.trimmedOrNil : nil,
                                startAt: draft.allDay ? nil : draft.startAt,
                                timezone: TimeZone.current.identifier,
                                recurrence: draft.recurrence,
                                projectId: draft.spaceType == .company ? draft.projectId : nil
                            )
                        )
                        try await model.loadAllData()
                    }
                }
            }
            .refreshable {
                await reload()
            }
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
            .task {
                await reload()
            }
        }
    }

    private func reload() async {
        switch filter {
        case "personal":
            await model.reloadCalendar(filter: .personal)
        case "company":
            await model.reloadCalendar(filter: .company)
        case "project":
            if let selectedProjectId {
                await model.reloadCalendar(filter: .project(selectedProjectId))
            }
        default:
            await model.reloadCalendar(filter: .all)
        }
    }

    private func delete(_ item: CalendarItem) async {
        await model.run {
            _ = try await model.calendarRepository.delete(id: item.id)
            try await model.loadAllData()
        }
    }

    private func draft(from item: CalendarItem) -> IOSCalendarDraft {
        IOSCalendarDraft(
            spaceType: item.spaceId == model.companySpace?.id ? .company : .personal,
            title: item.title,
            description: item.description ?? "",
            type: item.type,
            allDay: item.allDay,
            startDate: item.startDate ?? "",
            startAt: item.startAt ?? Date(),
            recurrence: item.recurrence ?? .none,
            projectId: item.projectId
        )
    }
}

private struct IOSCalendarDraft {
    var spaceType: SpaceType = .personal
    var title = ""
    var description = ""
    var type: CalendarItemType = .appointment
    var allDay = false
    var startDate = ""
    var startAt = Date()
    var recurrence: Recurrence = .none
    var projectId: String?
}

private struct IOSCalendarItemForm: View {
    let title: String
    let projects: [Project]
    let allowsOwnershipChange: Bool
    let save: (IOSCalendarDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: IOSCalendarDraft

    init(
        title: String = "New Calendar Item",
        projects: [Project],
        initialDraft: IOSCalendarDraft = IOSCalendarDraft(),
        allowsOwnershipChange: Bool = true,
        save: @escaping (IOSCalendarDraft) async -> Void
    ) {
        self.title = title
        self.projects = projects
        self.allowsOwnershipChange = allowsOwnershipChange
        self.save = save
        self._draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ownership") {
                    if allowsOwnershipChange {
                        Picker("Space", selection: $draft.spaceType) {
                            ForEach(SpaceType.allCases) { space in
                                Text(space.label).tag(space)
                            }
                        }
                    } else {
                        LabeledContent("Space", value: draft.spaceType.label)
                    }
                    if draft.spaceType == .company {
                        Picker("Project", selection: $draft.projectId) {
                            Text("No Project").tag(Optional<String>.none)
                            ForEach(projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                    }
                }

                Section("Item") {
                    TextField("Title", text: $draft.title)
                    TextField("Description", text: $draft.description, axis: .vertical)
                    Picker("Type", selection: $draft.type) {
                        ForEach(CalendarItemType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    Toggle("All day", isOn: $draft.allDay)
                    if draft.allDay {
                        TextField("Start date (YYYY-MM-DD)", text: $draft.startDate)
                    } else {
                        DatePicker("Start time", selection: $draft.startAt)
                    }
                    Picker("Recurrence", selection: $draft.recurrence) {
                        ForEach(Recurrence.allCases) { recurrence in
                            Text(recurrence.label).tag(recurrence)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (draft.allDay && draft.startDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
        }
    }
}
#endif
