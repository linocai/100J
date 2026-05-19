import SwiftUI

#if os(macOS)
struct MacWorkbenchShellView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inspectorSelection: InspectorSelection?
    @State private var quickCaptureText = ""
    @State private var showingQuickCapture = false
    @State private var showingInspectorPopover = false
    @FocusState private var isQuickCaptureFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let showsInspector = width >= AppTheme.Layout.inspectorVisibilityThreshold
            let sidebarColumnWidth = sidebarWidth(for: width)
            let inspectorColumnWidth = showsInspector ? inspectorWidth(for: width) : 0
            let separatorWidth: CGFloat = showsInspector ? 2 : 1
            let centerWidth = max(0, width - sidebarColumnWidth - inspectorColumnWidth - separatorWidth)
            let layout = WorkbenchLayoutContext(
                windowWidth: width,
                centerWidth: centerWidth,
                showsInspector: showsInspector
            )
            VStack(spacing: 0) {
                CommandTopBar(
                    quickCaptureText: $quickCaptureText,
                    isQuickCaptureFocused: $isQuickCaptureFocused,
                    primaryAction: primaryAction,
                    showsInspectorButton: !showsInspector,
                    onSubmitQuickCapture: openQuickCapture,
                    onPrimaryAction: runPrimaryAction,
                    onToggleInspector: { showingInspectorPopover.toggle() }
                )
                .environment(\.workbenchLayout, layout)

                horizontalHairline

                HStack(spacing: 0) {
                    MacSidebarView(selection: $model.selectedSection)
                        .frame(width: sidebarColumnWidth)

                    verticalHairline

                    currentWorkspace
                        .frame(minWidth: 0, maxWidth: contentMaxWidth(for: layout), maxHeight: .infinity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                        .layoutPriority(1)
                        .environment(\.workbenchLayout, layout)

                    if showsInspector {
                        verticalHairline
                        ContextInspectorView(selection: inspectorSelection)
                            .frame(width: inspectorColumnWidth)
                            .environment(\.workbenchLayout, layout)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppBackgroundView())
        }
        .frame(
            minWidth: AppTheme.Layout.minimumWindowWidth,
            minHeight: AppTheme.Layout.minimumWindowHeight
        )
        .sheet(isPresented: $showingQuickCapture) {
            QuickCaptureSheet(rawText: quickCaptureText) {
                quickCaptureText = ""
            }
            .environmentObject(model)
        }
        .popover(isPresented: $showingInspectorPopover) {
            ContextInspectorView(selection: inspectorSelection)
                .environmentObject(model)
                .frame(
                    width: AppTheme.Layout.inspectorPopoverWidth,
                    height: AppTheme.Layout.inspectorPopoverHeight
                )
        }
    }

    @ViewBuilder
    private var currentWorkspace: some View {
        switch model.selectedSection ?? .today {
        case .today:
            TodayCommandView(
                selection: inspectorSelection,
                selectTask: { inspectorSelection = .task($0.id) },
                selectCalendarItem: { inspectorSelection = .calendarItem($0.id) },
                jumpToSection: { model.selectedSection = $0 }
            )
        case .personalTasks:
            PersonalTasksView(selection: inspectorSelection, onSelectTask: { inspectorSelection = .task($0.id) })
        case .personalNotes:
            PersonalNotesView(selection: inspectorSelection, onSelectNote: { inspectorSelection = .note($0.id) })
        case .companyTasks:
            CompanyWorkbenchView(
                selection: inspectorSelection,
                selectTask: { inspectorSelection = .task($0.id) },
                selectProject: { inspectorSelection = .project($0.id) }
            )
        case .companyProjects:
            CompanyProjectsView(selection: inspectorSelection, onSelectProject: { inspectorSelection = .project($0.id) })
        case .calendar:
            GlobalCalendarView(selection: inspectorSelection, onSelectCalendarItem: { inspectorSelection = .calendarItem($0.id) })
        case .agent:
            AgentView(onSelectAgentLog: { inspectorSelection = .agentLog($0.id) })
        case .settings:
            SettingsView()
        }
    }

    private var horizontalHairline: some View {
        Rectangle()
            .fill(AppTheme.Colors.hairline)
            .frame(height: 1)
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(AppTheme.Colors.hairline)
            .frame(width: 1)
    }

    private func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        if windowWidth >= AppTheme.Layout.wideWindowThreshold {
            return AppTheme.Layout.sidebarWideWidth
        }
        if windowWidth >= AppTheme.Layout.inspectorVisibilityThreshold {
            return AppTheme.Layout.sidebarRegularWidth
        }
        return AppTheme.Layout.sidebarCompactWidth
    }

    private func inspectorWidth(for windowWidth: CGFloat) -> CGFloat {
        windowWidth >= AppTheme.Layout.wideWindowThreshold
            ? AppTheme.Layout.inspectorWideWidth
            : AppTheme.Layout.inspectorRegularWidth
    }

    private func contentMaxWidth(for layout: WorkbenchLayoutContext) -> CGFloat? {
        if model.selectedSection == .companyTasks { return nil }
        if layout.centerWidth < AppTheme.Layout.centerContentCompactThreshold { return nil }
        return layout.windowWidth >= AppTheme.Layout.wideWindowThreshold
            ? AppTheme.Layout.centerContentWideMaxWidth
            : AppTheme.Layout.centerContentRegularMaxWidth
    }

    private var primaryAction: PrimaryActionDescriptor {
        switch model.selectedSection ?? .today {
        case .today:
            return PrimaryActionDescriptor(title: "New Capture", systemImage: "plus")
        case .personalTasks:
            return PrimaryActionDescriptor(title: "Personal Task", systemImage: "checklist")
        case .personalNotes:
            return PrimaryActionDescriptor(title: "New Idea", systemImage: "lightbulb")
        case .companyTasks:
            return PrimaryActionDescriptor(title: "Company Task", systemImage: "rectangle.3.group")
        case .companyProjects:
            return PrimaryActionDescriptor(title: "New Project", systemImage: "folder.badge.plus")
        case .calendar:
            return PrimaryActionDescriptor(title: "Event", systemImage: "calendar.badge.plus")
        case .agent:
            return PrimaryActionDescriptor(title: "Send", systemImage: "paperplane")
        case .settings:
            return PrimaryActionDescriptor(title: "Refresh", systemImage: "arrow.clockwise")
        }
    }

    private func runPrimaryAction() {
        switch model.selectedSection ?? .today {
        case .personalTasks:
            quickCaptureText = "个人待办 "
            openQuickCapture()
        case .personalNotes:
            quickCaptureText = "灵感 "
            openQuickCapture()
        case .companyTasks:
            quickCaptureText = "公司待办 "
            openQuickCapture()
        case .companyProjects:
            quickCaptureText = "新项目 "
            openQuickCapture()
        case .calendar:
            quickCaptureText = "固定日程 "
            openQuickCapture()
        case .agent:
            model.selectedSection = .agent
            isQuickCaptureFocused = true
        case .settings:
            Task { await model.refreshAll() }
        case .today:
            openQuickCapture()
        }
    }

    private func openQuickCapture() {
        isQuickCaptureFocused = false
        showingQuickCapture = true
    }
}
#endif
