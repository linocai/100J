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
                title: "选择它应该落在哪里",
                subtitle: "在你明确选择待办、固定日程或备忘之前，100J 不会自动写入。"
            )

            SurfaceView(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("原始输入")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                    Text(draft.rawText.isEmpty ? "未命名记录" : draft.rawText)
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Picker("落点", selection: $draft.target) {
                ForEach(CaptureTarget.allCases) { target in
                    Text(target.label).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.target) { _ in
                normalizeDraftForTarget()
            }

            Form {
                TextField("标题", text: $draft.title)
                TextField("描述", text: $draft.description, axis: .vertical)
                    .lineLimit(2...5)

                switch draft.target {
                case .personalTask:
                    taskFields(allowsProject: false)
                case .companyTask:
                    taskFields(allowsProject: true)
                case .fixedCalendar:
                    calendarFields
                case .personalNote:
                    Picker("备忘类型", selection: $draft.noteType) {
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
                Button("取消") { dismiss() }
                Button("保存") {
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
        Picker("优先级", selection: $draft.priority) {
            ForEach(TaskPriority.allCases) { priority in
                Text(priority.label).tag(priority)
            }
        }
        Toggle("设置截止日期", isOn: $draft.hasDueDate)
        if draft.hasDueDate {
            DatePicker("截止日期", selection: $draft.dueDate, displayedComponents: .date)
        }
        if allowsProject {
            Picker("项目", selection: $draft.projectId) {
                Text("无项目").tag(Optional<String>.none)
                ForEach(model.projects) { project in
                    Text(project.name).tag(Optional(project.id))
                }
            }
        }
    }

    private var calendarFields: some View {
        Group {
            Picker("空间", selection: $draft.calendarSpace) {
                ForEach(SpaceType.allCases) { space in
                    Text(space.label).tag(space)
                }
            }
            Picker("类型", selection: $draft.calendarType) {
                ForEach(CalendarItemType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            Toggle("全天", isOn: $draft.allDay)
            if draft.allDay {
                DatePicker("开始日期", selection: $draft.startDate, displayedComponents: .date)
            } else {
                DatePicker("开始时间", selection: $draft.startAt)
            }
            Picker("重复", selection: $draft.recurrence) {
                ForEach(Recurrence.allCases) { recurrence in
                    Text(recurrence.label).tag(recurrence)
                }
            }
            if draft.calendarSpace == .company {
                Picker("项目", selection: $draft.projectId) {
                    Text("无项目").tag(Optional<String>.none)
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
                            dueDate: draft.dueDateString
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
                            dueDate: draft.dueDateString
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
                            startDate: draft.allDay ? draft.startDateString : nil,
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
            return "保存前请先填写标题。"
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
