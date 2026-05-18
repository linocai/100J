#if os(iOS)
import SwiftUI

struct IOSSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IOSScreenHeader(title: "设置", subtitle: "本地 API、未来云端 API 和钥匙串会话配置。")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("API") {
                    TextField("Base URL", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button("保存 API URL") {
                        model.updateBaseURL(baseURL)
                    }
                    Button("刷新数据") {
                        Task { await model.refreshAll() }
                    }
                }

                Section("账号") {
                    Text("登录 token 保存在 Apple 钥匙串；退出登录会清理本机会话。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let user = model.currentUser {
                        LabeledContent("用户", value: user.email ?? user.id)
                        LabeledContent("时区", value: user.timezone)
                    }
                    Button("退出登录", role: .destructive) {
                        Task { await model.logout() }
                    }
                }

                Section("空间") {
                    if let personal = model.personalSpace {
                        LabeledContent("个人", value: personal.id)
                    }
                    if let company = model.companySpace {
                        LabeledContent("公司", value: company.id)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
        }
    }
}
#endif
