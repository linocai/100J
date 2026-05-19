import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isAuthenticated {
                #if os(iOS)
                IOSMainShellView()
                #else
                MacWorkbenchShellView()
                #endif
            } else {
                AuthView()
            }
        }
        .overlay(alignment: .bottom) {
            if let message = model.errorMessage {
                ErrorBanner(message: message) {
                    model.errorMessage = nil
                }
                .padding()
            }
        }
        #if os(macOS)
        .background(MacWindowChromeConfigurator())
        #endif
    }
}

#if os(macOS)
// Legacy fallback only. Do not use this as the macOS product shell.
struct LegacyMainShellView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                Section("焦点") {
                    SidebarRow(section: .today)
                    SidebarRow(section: .calendar)
                }
                Section("个人") {
                    SidebarRow(section: .personalTasks)
                    SidebarRow(section: .personalNotes)
                }
                Section("公司") {
                    SidebarRow(section: .companyTasks)
                    SidebarRow(section: .companyProjects)
                }
                Section("系统") {
                    SidebarRow(section: .agent)
                    SidebarRow(section: .settings)
                }
            }
            .navigationTitle("事务")
            .toolbar {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
        } detail: {
            Group {
                switch model.selectedSection ?? .today {
                case .today:
                    TodayCommandView(selectTask: { _ in }, selectCalendarItem: { _ in }, jumpToSection: { model.selectedSection = $0 })
                case .personalTasks:
                    PersonalTasksView()
                case .personalNotes:
                    PersonalNotesView()
                case .companyTasks:
                    LegacyCompanyTasksView()
                case .companyProjects:
                    CompanyProjectsView()
                case .calendar:
                    GlobalCalendarView()
                case .agent:
                    AgentView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

private struct SidebarRow: View {
    let section: AppSection

    var body: some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.systemImage)
        }
    }
}
#endif
