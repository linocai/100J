import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    eyebrow: "系统",
                    title: "设置",
                    subtitle: "API Base URL、钥匙串会话状态和恢复操作。",
                    systemImage: "gearshape"
                )
                SurfaceView {
                    Form {
                        TextField("API Base URL", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("保存 API URL") {
                                model.updateBaseURL(baseURL)
                            }
                            Button("刷新数据") {
                                Task { await model.refreshAll() }
                            }
                            Button("退出登录") {
                                Task { await model.logout() }
                            }
                        }
                        Text("Access token 与 refresh token 保存在 Apple 钥匙串；退出登录会清理本机钥匙串会话。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let user = model.currentUser {
                            LabeledContent("用户", value: user.email ?? user.id)
                            LabeledContent("时区", value: user.timezone)
                        }
                        if let personal = model.personalSpace {
                            LabeledContent("个人空间", value: personal.id)
                        }
                        if let company = model.companySpace {
                            LabeledContent("公司空间", value: company.id)
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
