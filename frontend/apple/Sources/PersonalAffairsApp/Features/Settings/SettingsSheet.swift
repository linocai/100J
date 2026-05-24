import PersonalAffairsCore
import SwiftUI

/// 设置 sheet —— 必有 Done 按钮，下拉可关。
/// 5 段：账号 / 连接 / 数据 / Agent / 关于。
struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @State private var llmProvider: String = "openai"
    @State private var llmKeyDraft: String = ""
    @State private var showingLLMSheet = false
    @State private var showingCloudSetupConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                connectionSection
                dataSection
                agentSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { isPresented = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .confirmationDialog(
            "连接个人云端",
            isPresented: $showingCloudSetupConfirmation,
            titleVisibility: .visible
        ) {
            Button("进入云端绑定", role: .destructive) {
                if model.prepareCloudOwnerSetup() {
                    isPresented = false
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会退出当前本地/设备会话，并回到访问码绑定页。Mac 和 iPhone 的登录态不会自动共享。")
        }
        .sheet(isPresented: $showingLLMSheet) {
            LLMKeyEditor(provider: $llmProvider, apiKey: $llmKeyDraft) {
                Task {
                    await model.saveLLMKey(provider: llmProvider, apiKey: llmKeyDraft)
                    llmKeyDraft = ""
                    showingLLMSheet = false
                }
            } cancel: {
                llmKeyDraft = ""
                showingLLMSheet = false
            }
            #if os(macOS)
            .frame(width: 420, height: 280)
            #else
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    // MARK: 账号 / 设备

    private var accountSection: some View {
        Section {
            HStack(spacing: AppTheme.Spacing.md) {
                AvatarBadge(initial: String(userName.prefix(1)), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(.headline)
                    Text(model.currentUser?.email ?? model.authMode.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                SyncStatusDot(state: model.syncStatus)
            }
            .padding(.vertical, 4)

            if let session = model.deviceSessionInfo {
                LabeledContent("本设备", value: session.deviceName)
                LabeledContent("已登录", value: "\(daysSince(session.lastRefreshedAt)) 天")
                if let expires = session.expiresAt {
                    LabeledContent("到期", value: relativeDate(expires))
                        .font(.footnote)
                }
            }

            Button(role: .destructive) {
                Task {
                    await model.logout()
                    isPresented = false
                }
            } label: {
                Label("退出本设备", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } header: {
            Text("账号 · 设备")
        } footer: {
            Text("退出会撤销服务器端的设备会话；下次打开需要重新输入访问码。")
        }
    }

    private func daysSince(_ date: Date) -> Int {
        max(1, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 1)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日"
        return f.string(from: date)
    }

    private var userName: String {
        model.currentUser?.displayName?.nilIfBlank
            ?? model.currentUser?.email?.nilIfBlank
            ?? "100J User"
    }

    // MARK: 连接

    private var connectionSection: some View {
        Section {
            LabeledContent("模式", value: model.authMode.label)
            LabeledContent("服务器", value: model.apiServerHost)
            Text(model.apiBaseURLString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)

            if model.isLocalDevelopmentConnection {
                Label {
                    Text("当前是本地开发连接。iPhone 上的 127.0.0.1 指向手机本机，不会连接你的 Mac 或云服务器。")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .foregroundStyle(.orange)
            }

            Button {
                showingCloudSetupConfirmation = true
            } label: {
                Label(cloudSetupButtonTitle, systemImage: "cloud.fill")
            }
        } header: {
            Text("连接")
        } footer: {
            Text("每台设备都需要单独绑定云端访问码；Mac 已连接不会自动让 iPhone 登录。")
        }
    }

    private var cloudSetupButtonTitle: String {
        if model.authMode == .cloudJWT, model.currentUser != nil {
            return "重新绑定个人云端"
        }
        return "连接个人云端"
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            LabeledContent("个人任务", value: "\(model.activePersonalTasks.count) 项")
            LabeledContent("公司任务", value: "\(model.activeCompanyTasks.count) 项")
            LabeledContent("项目", value: "\(model.projects.count) 项")
            LabeledContent("笔记", value: "\(model.notes.count) 条")
            LabeledContent("日程", value: "\(model.calendarItems.count) 条")
            Button {
                // v1.2.4 P6-4 (#27): "立即同步" is an explicit user action and
                // should always bypass the 30 s throttle.
                Task { await model.refreshAll(force: true) }
            } label: {
                Label("立即同步", systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            if model.pendingMutationCount > 0 {
                Label("\(model.pendingMutationCount) 条离线操作待重放", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("数据")
        }
    }

    // MARK: Agent

    private var agentSection: some View {
        Section {
            if let key = model.llmKey, key.isActive {
                LabeledContent("LLM Provider", value: key.provider)
                if let preview = key.keyPreview {
                    LabeledContent("Key 预览", value: preview)
                        .font(.callout.monospaced())
                }
            } else {
                LabeledContent("LLM Key") {
                    Text("未配置").foregroundStyle(.orange)
                }
            }
            Button {
                llmProvider = model.llmKey?.provider ?? "openai"
                showingLLMSheet = true
            } label: {
                Label(model.llmKey?.isActive == true ? "更新 LLM Key" : "配置 LLM Key",
                      systemImage: "key.fill")
            }
        } header: {
            Text("Agent")
        } footer: {
            Text("仅密文存储在云端；服务器只保留前 3 / 后 4 位预览。Agent 写操作仍会走二次确认。")
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        Section {
            LabeledContent("版本", value: appVersion)
            LabeledContent("构建", value: appBuild)
            Link(destination: URL(string: "https://100j.linotsai.top/privacy")!) {
                Label("隐私政策", systemImage: "lock.shield")
            }
            Link(destination: URL(string: "https://100j.linotsai.top/terms")!) {
                Label("服务条款", systemImage: "doc.text")
            }
        } header: {
            Text("关于")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
    }

}

private struct LLMKeyEditor: View {
    @Binding var provider: String
    @Binding var apiKey: String
    let save: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Provider", text: $provider)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                    SecureField("API Key", text: $apiKey)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    Text("例：openai · anthropic · deepseek。Key 会以 Fernet 加密保存在服务器，仅 Agent 调用时解密。")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("LLM Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
