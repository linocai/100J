#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSSettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://100j.linotsai.top/api/v1"
    @State private var selectedAuthMode = UserDefaults.standard.string(forKey: "appAuthMode").flatMap(AppAuthMode.init(rawValue:)) ?? .cloudJWT

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IOSScreenHeader(title: "设置", subtitle: "个人云端 API、同步状态和高级连接配置。")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("模式") {
                    Picker("当前模式", selection: $selectedAuthMode) {
                        ForEach(AppAuthMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .onValueChange(of: selectedAuthMode) { newValue in
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
                    Text(model.authMode == .localOwner ? "本机 Owner 模式不使用 Keychain 或 Authorization header。" : "个人云端 token 保存在 Apple 钥匙串。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.authMode == .cloudJWT {
                        Button("退出个人云端", role: .destructive) {
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
            .task {
                selectedAuthMode = model.authMode
            }
            .onValueChange(of: model.authMode) { newValue in
                if selectedAuthMode != newValue {
                    selectedAuthMode = newValue
                }
            }
        }
    }
}
#endif
