#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IOSScreenHeader(title: "设置", subtitle: "本机服务、未来云端 API 和高级连接配置。")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("模式") {
                    Picker("当前模式", selection: $model.authMode) {
                        ForEach(AppAuthMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .onChange(of: model.authMode) { newValue in
                        model.updateAuthMode(newValue)
                    }
                    if let user = model.currentUser {
                        LabeledContent("用户", value: user.displayName ?? user.email ?? user.id)
                        LabeledContent("时区", value: user.timezone)
                    }
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
                    Text(model.authMode == .localOwner ? "本机 Owner 模式不使用 Keychain 或 Authorization header。" : "云端登录 token 保存在 Apple 钥匙串。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.authMode == .cloudJWT {
                        Button("退出登录", role: .destructive) {
                            Task { await model.logout() }
                        }
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
