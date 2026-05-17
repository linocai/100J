#if os(iOS)
import SwiftUI

struct IOSSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IOSScreenHeader(title: "Settings", subtitle: "Local and future cloud API configuration.")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("API") {
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("Save API URL") {
                        model.updateBaseURL(baseURL)
                    }
                    Button("Refresh Data") {
                        Task { await model.refreshAll() }
                    }
                }

                Section("Account") {
                    if let user = model.currentUser {
                        LabeledContent("User", value: user.email ?? user.id)
                        LabeledContent("Timezone", value: user.timezone)
                    }
                    Button("Logout", role: .destructive) {
                        Task { await model.logout() }
                    }
                }

                Section("Spaces") {
                    if let personal = model.personalSpace {
                        LabeledContent("Personal", value: personal.id)
                    }
                    if let company = model.companySpace {
                        LabeledContent("Company", value: company.id)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
        }
    }
}
#endif

