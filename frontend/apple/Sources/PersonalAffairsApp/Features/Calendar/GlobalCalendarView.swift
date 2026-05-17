import PersonalAffairsCore
import SwiftUI

struct GlobalCalendarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter = "all"
    @State private var selectedProjectId: String?
    @State private var showingNewItem = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.calendarItems.isEmpty {
                EmptyStateView(title: "No calendar items", message: "Fixed dates and fixed times across Personal and Company appear here.")
            } else {
                List(model.calendarItems) { item in
                    CalendarItemRow(
                        item: item,
                        space: spaceLabel(item.spaceId, spaces: model.spaces),
                        project: projectName(item.projectId, projects: model.projects),
                        delete: { delete(item) }
                    )
                }
            }
        }
        .sheet(isPresented: $showingNewItem) {
            CalendarItemFormView(projects: model.projects) { draft in
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
        .task { await reload() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ToolbarTitle(title: "Global Calendar", subtitle: "Personal and Company fixed-time items in one timeline.")
            Spacer()
            Picker("Filter", selection: $filter) {
                Text("All").tag("all")
                Text("Personal").tag("personal")
                Text("Company").tag("company")
                Text("Project").tag("project")
            }
            .frame(width: 140)
            .onChange(of: filter) { _ in Task { await reload() } }

            if filter == "project" {
                Picker("Project", selection: $selectedProjectId) {
                    Text("Choose").tag(Optional<String>.none)
                    ForEach(model.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .frame(width: 180)
                .onChange(of: selectedProjectId) { _ in Task { await reload() } }
            }

            Button {
                showingNewItem = true
            } label: {
                Label("New Item", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
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

    private func delete(_ item: CalendarItem) {
        Task {
            await model.run {
                _ = try await model.calendarRepository.delete(id: item.id)
                try await model.loadAllData()
            }
        }
    }
}

private struct CalendarItemRow: View {
    let item: CalendarItem
    let space: String
    let project: String
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(item.allDay ? .orange : .blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack {
                    BadgeText(text: space, color: space == "Personal" ? .green : .blue)
                    BadgeText(text: item.type.label)
                    BadgeText(text: item.allDay ? (item.startDate ?? "All day") : (item.startAt?.shortDateTime ?? "Timed"))
                    if item.projectId != nil {
                        BadgeText(text: project, color: .blue)
                    }
                    if item.source == "agent" {
                        BadgeText(text: "Agent", color: .indigo)
                    }
                }
            }
            Spacer()
            Button(action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
        .padding(.vertical, 6)
    }

    private var icon: String {
        switch item.type {
        case .appointment: return "calendar"
        case .anniversary: return "gift"
        case .subscriptionExpiry: return "creditcard"
        case .deadline: return "flag"
        case .reminder: return "bell"
        }
    }
}

private struct CalendarDraft {
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

private struct CalendarItemFormView: View {
    let projects: [Project]
    let save: (CalendarDraft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CalendarDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Calendar Item")
                .font(.title2.weight(.semibold))
            Form {
                Picker("Space", selection: $draft.spaceType) {
                    ForEach(SpaceType.allCases) { space in
                        Text(space.label).tag(space)
                    }
                }
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
                if draft.spaceType == .company {
                    Picker("Project", selection: $draft.projectId) {
                        Text("No Project").tag(Optional<String>.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                }
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
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (draft.allDay && draft.startDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding()
        .frame(width: 500)
    }
}

