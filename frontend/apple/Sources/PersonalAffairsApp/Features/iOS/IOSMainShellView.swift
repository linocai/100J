#if os(iOS)
import SwiftUI

struct IOSMainShellView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            IOSPersonalView()
                .tabItem {
                    Label("Personal", systemImage: "person")
                }

            IOSCompanyView()
                .tabItem {
                    Label("Company", systemImage: "briefcase")
                }

            IOSCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            IOSAgentView()
                .tabItem {
                    Label("Agent", systemImage: "sparkles")
                }

            IOSSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
#endif

