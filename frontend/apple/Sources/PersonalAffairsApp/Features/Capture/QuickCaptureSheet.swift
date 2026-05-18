import PersonalAffairsCore
import SwiftUI

struct QuickCaptureSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CaptureDraft
    let onSaved: () -> Void

    init(rawText: String, onSaved: @escaping () -> Void) {
        _draft = State(initialValue: CaptureDraft(rawText: rawText))
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            SectionHeaderView(
                eyebrow: "Quick Capture",
                title: "Choose where this belongs",
                subtitle: "100J does not write automatically until you choose Task, Fixed Calendar, or Note."
            )

            SurfaceView(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Raw input")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                    Text(draft.rawText.isEmpty ? "Untitled capture" : draft.rawText)
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Picker("Target", selection: $draft.target) {
                ForEach(CaptureTarget.allCases) { target in
                    Text(target.label).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.target) { _ in
                normalizeDraftForTarget()
            }

            Form {
                TextField("Title", text: $draft.title)
                TextField("Description", text: $draft.description, axis: .vertical)
                    .lineLimit(2...5)

                switch draft.target {
                case .personalTask:
                    taskFields(allowsProject: false)
                case .companyTask:
                    taskFields(allowsProject: true)
                case .fixedCalendar:
                    calendarFields
                case .personalNote:
                    Picker("Note type", selection: $draft.noteType) {
                        ForEach(NoteType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.warningAccent)
                    .padding(.horizontal, AppTheme.Spacing.sm)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationMessage != nil)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(width: 560)
        .onChange(of: draft.calendarType) { newValue in
            if newValue == .anniversary || newValue == .subscriptionExpiry {
                draft.allDay = true
                if draft.recurrence == .none && newValue == .anniversary {
                    draft.recurrence = .yearly
                }
            }
        }
    }

    @ViewBuilder
    private func taskFields(allowsProject: Bool) -> some View {
        Picker("Priority", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
                Text(priority.label).tag(priority)
            }
        }
        TextField("Due date (YYYY-MM-DD)", text: $draft.dueDate)
        if allowsProject {
            Picker("Project", selection: $draft.projectId) {
                Text("No Project").tag(Optional<String>.none)
                ForEach(model.projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
        }
    }

    private var calendarFields: some View {
        Group {
            Picker("Space", selection: $draft.calendarSpace) {
                ForEach(SpaceType.allCases) { space in
                    Text(space.label).tag(space)
                }
            }
            Picker("Type", selection: $draft.calendarType) {
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
            if draft.calendarSpace == .company {
                Picker("Project", selection: $draft.projectId) {
                    Text("No Project").tag(Optional<String>.none)
                    ForEach(model.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
            }
        }
    }

    private func save() {
        guard validationMessage == nil else { return }

        Task {
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = draft.description.trimmedOrNil

            await model.run {
                switch draft.target {
                case .personalTask:
                    guard let space = model.personalSpace else { return }
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            title: title,
                            description: description,
                            priority: draft.priority,
                            dueDate: draft.dueDate.trimmedOrNil
                        )
                    )
                case .companyTask:
                    guard let space = model.companySpace else { return }
                    _ = try await model.taskRepository.create(
                        TaskCreateRequest(
                            spaceId: space.id,
                            projectId: draft.projectId,
                            title: title,
                            description: description,
                            priority: draft.priority,
                            dueDate: draft.dueDate.trimmedOrNil
                        )
                    )
                case .fixedCalendar:
                    let targetSpace = draft.calendarSpace == .personal ? model.personalSpace : model.companySpace
                    guard let space = targetSpace else { return }
                    _ = try await model.calendarRepository.create(
                        CalendarItemCreateRequest(
                            spaceId: space.id,
                            title: title,
                            description: description,
                            type: draft.calendarType,
                            allDay: draft.allDay,
                            startDate: draft.allDay ? draft.startDate.trimmedOrNil : nil,
                            startAt: draft.allDay ? nil : draft.startAt,
                            timezone: TimeZone.current.identifier,
                            recurrence: draft.recurrence,
                            projectId: draft.calendarSpace == .company ? draft.projectId : nil
                        )
                    )
                case .personalNote:
                    guard let space = model.personalSpace else { return }
                    _ = try await model.noteRepository.create(
                        NoteCreateRequest(
                            spaceId: space.id,
                            title: title,
                            body: draft.description.trimmedOrNil ?? draft.rawText.trimmedOrNil ?? title,
                            type: draft.noteType
                        )
                    )
                }
                try await model.loadAllData()
            }

            onSaved()
            dismiss()
        }
    }

    private var validationMessage: String? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return "Add a title before saving."
        }

        if draft.target == .fixedCalendar && draft.allDay && draft.startDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "All-day fixed items need a start date."
        }

        return nil
    }

    private func normalizeDraftForTarget() {
        switch draft.target {
        case .personalTask:
            draft.projectId = nil
        case .companyTask:
            break
        case .fixedCalendar:
            if draft.calendarType == .anniversary || draft.calendarType == .subscriptionExpiry {
                draft.allDay = true
            }
        case .personalNote:
            draft.projectId = nil
        }
    }
}
