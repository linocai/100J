#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSTodayScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingSettings = false

    var body: some View {
        List {
            Section {
                IOSScreenHeader(title: "Today", subtitle: "三件焦点、接下来，以及还没归位的尾巴。")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            Section("Top 3") {
                if filteredTopThree.isEmpty {
                    IOSUnavailableView(title: "暂无 Top 3", systemImage: "scope", message: "按右上角加号，用一句话捕捉新事项。")
                } else {
                    ForEach(filteredTopThree) { task in
                        IOSTaskRow(task: task, projectName: model.projectName(for: task.projectId))
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await model.toggleTaskDone(task) }
                                } label: {
                                    Label(task.status == .done ? "重新打开" : "完成", systemImage: task.status == .done ? "arrow.uturn.left" : "checkmark")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await model.archiveTask(task) }
                                } label: {
                                    Label("归档", systemImage: "archivebox")
                                }
                            }
                    }
                }
            }

            Section("接下来") {
                if filteredUpcoming.isEmpty {
                    IOSUnavailableView(title: "暂无固定日程", systemImage: "calendar", message: "只有固定时间或固定日期事项进入 Calendar。")
                } else {
                    ForEach(filteredUpcoming) { schedule in
                        IOSCalendarRow(
                            item: schedule.item,
                            space: model.spaceLabel(for: schedule.item.spaceId),
                            project: model.projectName(for: schedule.item.projectId) ?? "无项目"
                        )
                    }
                }
            }

            Section("Loose Ends") {
                if filteredLooseEnds.isEmpty {
                    IOSUnavailableView(title: "Loose Ends 已清空", systemImage: "tray", message: "无项目公司任务和未转行动的灵感会出现在这里。")
                } else {
                    ForEach(filteredLooseEnds) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.kind == .task ? "tray" : "note.text")
                                .foregroundStyle(item.kind == .task ? .orange : .purple)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $model.search, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "person.crop.circle")
                }
                Button {
                    model.universalComposerViewModel.open()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            IOSSettingsSheet()
        }
        .refreshable { await model.refreshAll() }
        .overlay { IOSLoadingOverlay() }
        .iosErrorAlert()
        .task {
            model.todayViewModel.refresh()
        }
    }

    private var filteredTopThree: [TaskItem] {
        guard let term = model.search.trimmedOrNil else { return model.todayViewModel.topThree }
        return model.todayViewModel.topThree.filter { $0.matchesSearch(term, projectName: model.projectName(for: $0.projectId)) }
    }

    private var filteredUpcoming: [TodayScheduleItem] {
        guard let term = model.search.trimmedOrNil else { return model.todayViewModel.upcoming }
        return model.todayViewModel.upcoming.filter { $0.item.matchesSearch(term, projectName: model.projectName(for: $0.item.projectId)) }
    }

    private var filteredLooseEnds: [TodayLooseEnd] {
        guard let term = model.search.trimmedOrNil else { return model.todayViewModel.looseEnds }
        return model.todayViewModel.looseEnds.filter {
            $0.title.localizedCaseInsensitiveContains(term) || $0.subtitle.localizedCaseInsensitiveContains(term)
        }
    }
}
#endif
