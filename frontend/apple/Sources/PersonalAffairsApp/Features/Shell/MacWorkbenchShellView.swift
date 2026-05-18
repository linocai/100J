import SwiftUI

#if os(macOS)
struct MacWorkbenchShellView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inspectorSelection: InspectorSelection?
    @State private var quickCaptureText = ""
    @State private var showingQuickCapture = false
    @FocusState private var isQuickCaptureFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CommandTopBar(
                    quickCaptureText: $quickCaptureText,
                    isQuickCaptureFocused: $isQuickCaptureFocused,
                    onSubmitQuickCapture: openQuickCapture,
                    onNew: openQuickCapture
                )

                Divider()

                HStack(spacing: 0) {
                    MacSidebarView(selection: $model.selectedSection)
                        .frame(width: sidebarWidth(for: geometry.size.width))

                    Divider()

                    currentWorkspace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)

                    if geometry.size.width >= 1180 {
                        Divider()
                        ContextInspectorView(selection: inspectorSelection)
                            .frame(width: 324)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppBackgroundView())
        }
        .frame(minWidth: 900, minHeight: 680)
        .task { await model.refreshAll() }
        .sheet(isPresented: $showingQuickCapture) {
            QuickCaptureSheet(rawText: quickCaptureText) {
                quickCaptureText = ""
            }
            .environmentObject(model)
        }
    }

    @ViewBuilder
    private var currentWorkspace: some View {
        switch model.selectedSection ?? .today {
        case .today:
            TodayCommandView(
                selectTask: { inspectorSelection = .task($0.id) },
                selectCalendarItem: { inspectorSelection = .calendarItem($0.id) },
                jumpToSection: { model.selectedSection = $0 }
            )
        case .personalTasks:
            PersonalTasksView(onSelectTask: { inspectorSelection = .task($0.id) })
        case .personalNotes:
            PersonalNotesView(onSelectNote: { inspectorSelection = .note($0.id) })
        case .companyTasks:
            CompanyWorkbenchView(
                selectTask: { inspectorSelection = .task($0.id) },
                selectProject: { inspectorSelection = .project($0.id) }
            )
        case .companyProjects:
            CompanyProjectsView(onSelectProject: { inspectorSelection = .project($0.id) })
        case .calendar:
            GlobalCalendarView(onSelectCalendarItem: { inspectorSelection = .calendarItem($0.id) })
        case .agent:
            AgentView(onSelectAgentLog: { inspectorSelection = .agentLog($0.id) })
        case .settings:
            SettingsView()
        }
    }

    private func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        windowWidth < 980 ? 216 : 246
    }

    private func openQuickCapture() {
        isQuickCaptureFocused = false
        showingQuickCapture = true
    }
}
#endif
