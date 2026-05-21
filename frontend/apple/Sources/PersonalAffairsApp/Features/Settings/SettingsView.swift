import PersonalAffairsCore
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var baseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "https://100j.linotsai.top/api/v1"
    @State private var selectedAuthMode = UserDefaults.standard.string(forKey: "appAuthMode").flatMap(AppAuthMode.init(rawValue:)) ?? .cloudJWT
    @State private var provider = "openai"
    @State private var apiKey = ""
    @State private var showingAdvanced = false
    @State private var exportedDiagnosticsURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                SectionHeaderView(
                    eyebrow: "系统",
                    title: "设置",
                    subtitle: "本机服务状态、数据刷新、LLM Key 和高级连接设置。",
                    systemImage: "gearshape",
                    accent: AppTheme.Colors.tertiaryText
                )
                SurfaceView {
                    Form {
                        LabeledContent("当前模式") {
                            Picker("当前模式", selection: $selectedAuthMode) {
                                ForEach(AppAuthMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .onValueChange(of: selectedAuthMode) { newValue in
                                model.updateAuthMode(newValue)
                            }
                        }

                        if let user = model.currentUser {
                            LabeledContent("本机用户", value: user.displayName ?? user.email ?? user.id)
                            LabeledContent("时区", value: user.timezone)
                        } else if model.authMode == .localOwner {
                            LabeledContent("本机用户", value: "等待本机后端响应")
                        }

                        serviceStatus

                        HStack {
                            Button("刷新数据") {
                                Task { await model.refreshAll() }
                            }
                            .buttonStyle(.borderedProminent)

                            if model.authMode == .cloudJWT {
                                Button("退出个人云端") {
                                    Task { await model.logout() }
                                }
                            }
                        }

                        Section("LLM Key") {
                            if let key = model.llmKey, key.isActive {
                                LabeledContent("当前", value: "\(key.provider) \(key.keyPreview ?? "")")
                            } else {
                                Text("尚未保存 LLM Key")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                TextField("服务商", text: $provider)
                                    .textFieldStyle(.roundedBorder)
                                SecureField("API Key", text: $apiKey)
                                    .textFieldStyle(.roundedBorder)
                                Button("保存") {
                                    Task {
                                        await model.saveLLMKey(provider: provider, apiKey: apiKey)
                                        apiKey = ""
                                    }
                                }
                                .disabled(provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.isEmpty)
                            }
                        }

                        DisclosureGroup("高级连接设置", isExpanded: $showingAdvanced) {
                            TextField("API Base URL", text: $baseURL)
                                .textFieldStyle(.roundedBorder)
                            Button("保存 API URL") {
                                model.updateBaseURL(baseURL)
                            }
                            Text(model.authMode == .localOwner ? "本机 Owner 模式不使用 Keychain 或 Authorization header。" : "个人云端模式会使用 Apple 钥匙串保存 access token 与 refresh token。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let personal = model.personalSpace {
                                LabeledContent("个人空间", value: personal.id)
                            }
                            if let company = model.companySpace {
                                LabeledContent("公司空间", value: company.id)
                            }
                        }

                        Section("反馈与帮助") {
                            Link("联系作者", destination: FeedbackSupport.mailURL)
                            Link("GitHub Issues", destination: FeedbackSupport.issuesURL)
                            #if os(macOS)
                            Button("导出诊断包") {
                                exportDiagnosticsWithSavePanel()
                            }
                            #else
                            Button("准备诊断包") {
                                exportDiagnosticsForSharing()
                            }
                            if let exportedDiagnosticsURL {
                                ShareLink("分享诊断包", item: exportedDiagnosticsURL)
                            }
                            #endif
                            Text("诊断包只包含最近 24 小时的脱敏事件，不包含 token、headers、请求正文或 LLM Key。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    #if os(macOS)
                    .formStyle(.grouped)
                    #endif
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .task {
            selectedAuthMode = model.authMode
        }
        .onValueChange(of: model.authMode) { newValue in
            if selectedAuthMode != newValue {
                selectedAuthMode = newValue
            }
        }
    }

    @ViewBuilder
    private var serviceStatus: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(AppTheme.Colors.warningAccent)
        } else if let supportError = model.supportErrorMessage {
            Label("核心数据已加载，辅助数据待恢复：\(supportError)", systemImage: "info.circle")
                .foregroundStyle(AppTheme.Colors.warningAccent)
        } else {
            Label("本机服务连接正常", systemImage: "checkmark.circle")
                .foregroundStyle(AppTheme.Colors.successAccent)
        }
    }

    #if os(macOS)
    private func exportDiagnosticsWithSavePanel() {
        do {
            let sourceURL = try DiagnosticLogger.shared.exportLast24Hours()
            let panel = NSSavePanel()
            panel.nameFieldStringValue = sourceURL.lastPathComponent
            panel.allowedContentTypes = [.zip]
            guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            exportedDiagnosticsURL = destinationURL
        } catch {
            model.supportErrorMessage = UserFacingMessage.translate(error)
        }
    }
    #else
    private func exportDiagnosticsForSharing() {
        do {
            exportedDiagnosticsURL = try DiagnosticLogger.shared.exportLast24Hours()
        } catch {
            model.supportErrorMessage = UserFacingMessage.translate(error)
        }
    }
    #endif
}
