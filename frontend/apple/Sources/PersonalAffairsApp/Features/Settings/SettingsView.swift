import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ToolbarTitle(title: "Settings", subtitle: "Local API configuration and session controls.")
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
            .formStyle(.grouped)
            Spacer()
        }
        .padding()
    }
}

