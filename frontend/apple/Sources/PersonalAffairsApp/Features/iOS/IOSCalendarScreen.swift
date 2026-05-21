#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSCalendarScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var filter: CalendarScopeFilter = .all
    @State private var selectedProjectId: String?
    @State private var showingNewItem = false
    @State private var editingItem: CalendarItem?

    var body: some View {
        List {
                IOSScreenHeader(title: "日程", subtitle: "个人和公司的固定时间事项统一放在这里。")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)

                Section {
                    Picker("筛选", selection: $filter) {
                        ForEach(CalendarScopeFilter.allCases) { scope in
                            Text(scope.label).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onValueChange(of: filter) { _ in Task { await reload() } }

                    if filter == .project {
                        Picker("项目", selection: $selectedProjectId) {
                            Text("选择").tag(Optional<String>.none)
                            ForEach(model.projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                        .onValueChange(of: selectedProjectId) { _ in Task { await reload() } }
                    }
                }

                Section("日程") {
                    if filteredCalendarItems.isEmpty {
                        IOSUnavailableView(title: "暂无日程", systemImage: "calendar", message: "固定日期和约会会显示在这里。")
                    } else {
                        ForEach(filteredCalendarItems) { item in
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
                                    Task { await model.deleteCalendarItem(item) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("日程")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.search, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            Button {
                showingNewItem = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(item: $editingItem) { item in
            IOSCalendarItemForm(
                title: "编辑固定日程",
                projects: model.projects,
                initialDraft: CalendarDraftState(item: item, companySpaceId: model.companySpace?.id),
                allowsOwnershipChange: false
            ) { draft in
                await model.updateCalendarItem(id: item.id, draft: draft)
            }
        }
        .sheet(isPresented: $showingNewItem) {
            IOSCalendarItemForm(projects: model.projects) { draft in
                await model.createCalendarItem(draft)
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

    private func reload() async {
        guard let query = CalendarViewState.query(
            filter: filter,
            selectedProjectId: selectedProjectId,
            personalSpaceId: model.personalSpace?.id,
            companySpaceId: model.companySpace?.id
        ) else {
            model.calendarItems = []
            return
        }
        await model.reloadCalendar(query: query)
    }

    private var filteredCalendarItems: [CalendarItem] {
        guard let term = model.search.trimmedOrNil else { return model.calendarItems }
        return model.calendarItems.filter { $0.matchesSearch(term, projectName: model.projectName(for: $0.projectId)) }
    }
}

private struct IOSCalendarItemForm: View {
    let title: String
    let projects: [Project]
    let allowsOwnershipChange: Bool
    let save: (CalendarDraftState) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CalendarDraftState

    init(
        title: String = "新建固定日程",
        projects: [Project],
        initialDraft: CalendarDraftState = CalendarDraftState(),
        allowsOwnershipChange: Bool = true,
        save: @escaping (CalendarDraftState) async -> Void
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
                Section("归属") {
                    if allowsOwnershipChange {
                        Picker("空间", selection: $draft.spaceType) {
                            ForEach(SpaceType.allCases) { space in
                                Text(space.label).tag(space)
                            }
                        }
                    } else {
                        LabeledContent("空间", value: draft.spaceType.label)
                    }
                    if draft.spaceType == .company {
                        Picker("项目", selection: $draft.projectId) {
                            Text("无项目").tag(Optional<String>.none)
                            ForEach(projects) { project in
                                Text(project.name).tag(Optional(project.id))
                            }
                        }
                    }
                }

                Section("日程") {
                    TextField("标题", text: $draft.title)
                    TextField("描述", text: $draft.description, axis: .vertical)
                    Picker("类型", selection: $draft.type) {
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
                }

                Section("提醒") {
                    Toggle("开启提醒", isOn: $draft.hasReminder)
                    if draft.hasReminder {
                        DatePicker("提醒时间", selection: $draft.remindAt)
                        #if DEBUG
                        Button("5 秒后提醒") {
                            draft.hasReminder = true
                            draft.remindAt = Date().addingTimeInterval(5)
                        }
                        #endif
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
#endif
