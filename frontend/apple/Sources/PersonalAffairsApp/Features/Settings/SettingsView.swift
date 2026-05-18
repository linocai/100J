import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    eyebrow: "System",
                    title: "Settings",
                    subtitle: "API base URL, session state, and recovery actions.",
                    systemImage: "gearshape"
                )
                SurfaceView {
                    Form {
                        TextField("API base URL", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Save API URL") {
                                model.updateBaseURL(baseURL)
                            }
                            Button("Refresh Data") {
                                Task { await model.refreshAll() }
                            }
                            Button("Logout") {
                                Task { await model.logout() }
                            }
                        }
                        if let user = model.currentUser {
                            LabeledContent("User", value: user.email ?? user.id)
                            LabeledContent("Timezone", value: user.timezone)
                        }
                        if let personal = model.personalSpace {
                            LabeledContent("Personal Space", value: personal.id)
                        }
                        if let company = model.companySpace {
                            LabeledContent("Company Space", value: company.id)
                        }
                    }
                    #if os(macOS)
                    .formStyle(.grouped)
                    #endif
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
    }
}
