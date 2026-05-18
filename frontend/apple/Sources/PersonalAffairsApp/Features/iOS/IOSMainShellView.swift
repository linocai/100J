#if os(iOS)
import SwiftUI

struct IOSMainShellView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            IOSPersonalView()
                .tabItem {
                    Label("个人", systemImage: "person")
                }

            IOSCompanyView()
                .tabItem {
                    Label("公司", systemImage: "briefcase")
                }

            IOSCalendarView()
                .tabItem {
                    Label("日程", systemImage: "calendar")
                }

            IOSAgentView()
                .tabItem {
                    Label("Agent", systemImage: "sparkles")
                }

            IOSSettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
#endif
