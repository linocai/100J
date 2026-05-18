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
    }
}

#if os(macOS)
struct MainShellView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSection) {
                Section("Focus") {
                    SidebarRow(section: .today)
                    SidebarRow(section: .calendar)
                }
                Section("Personal") {
                    SidebarRow(section: .personalTasks)
                    SidebarRow(section: .personalNotes)
                }
                Section("Company") {
                    SidebarRow(section: .companyTasks)
                    SidebarRow(section: .companyProjects)
                }
                Section("System") {
                    SidebarRow(section: .agent)
                    SidebarRow(section: .settings)
                }
            }
            .navigationTitle("Affairs")
            .toolbar {
                Button {
                    Task { await model.refreshAll() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
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
                    CompanyTasksView()
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
