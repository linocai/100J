#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSAgentScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var provider = "openai"
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section {
                IOSScreenHeader(title: "Agent", subtitle: "App 内事务助理会先生成可审核操作；危险操作由后端要求二次确认。")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            Section("指令") {
                TextField("例如：公司待办 跟进发票 / 明天下午3点公司会议", text: $model.agentReview.inputText, axis: .vertical)
                    .lineLimit(2...5)
                Button {
                    model.composeAgentCommand()
                } label: {
                    Label("生成预览", systemImage: "sparkles")
                }
                .disabled(!model.agentReview.canCompose)
            }

            if let pendingCommand = model.agentReview.pendingCommand {
                Section("操作预览") {
                    commandSummary(pendingCommand)
                    Button {
                        Task { await model.executeAgentCommand(dryRun: true) }
                    } label: {
                        Label("预演", systemImage: "eye")
                    }
                    Button {
                        Task { await model.executeAgentCommand(dryRun: false) }
                    } label: {
                        Label("确认写入", systemImage: "checkmark.seal")
                    }
                }
            }

            if let pendingConfirmation = model.agentReview.pendingConfirmation {
                Section("二次确认") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pendingConfirmation.summary)
                            .font(.headline)
                        Text(pendingConfirmation.reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        IOSBadge(text: "后端要求确认", color: .orange)
                    }
                    Button(role: .cancel) {
                        model.cancelAgentCommand()
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                    Button {
                        Task { await model.confirmAgentCommand() }
                    } label: {
                        Label("确认执行", systemImage: "checkmark.seal")
                    }
                }
            }

            if !model.agentReview.responseText.isEmpty {
                Section("响应") {
                    Text(model.agentReview.responseText)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Section("LLM Key") {
                if let key = model.llmKey, key.isActive {
                    LabeledContent("当前", value: "\(key.provider) \(key.keyPreview ?? "")")
                } else {
                    Text("尚未保存 LLM Key")
                        .foregroundStyle(.secondary)
                }
                TextField("服务商", text: $provider)
                SecureField("API Key", text: $apiKey)
                Button("保存 Key") {
                    Task {
                        await model.saveLLMKey(provider: provider, apiKey: apiKey)
                        apiKey = ""
                    }
                }
                .disabled(provider.isEmpty || apiKey.isEmpty)
            }

            Section("操作日志") {
                ForEach(model.agentLogs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(log.actionType)
                            .font(.headline)
                        HStack {
                            IOSBadge(text: log.status, color: log.status == "success" ? .green : .orange)
                            if let targetType = log.targetType {
                                IOSBadge(text: targetType)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Agent")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.search, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            Button {
                model.universalComposerViewModel.open()
            } label: {
                Image(systemName: "plus")
            }
        }
        .refreshable {
            await model.reloadAgentSupport()
        }
        .overlay { IOSLoadingOverlay() }
        .iosErrorAlert()
        .task {
            await model.reloadAgentSupport()
        }
    }

    private func commandSummary(_ command: AgentCommandDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                IOSBadge(text: command.intent.target.label, color: .purple)
                IOSBadge(text: command.intent.calendarSpace.label, color: command.intent.calendarSpace == .personal ? .green : .blue)
            }
            Text(command.summary)
                .font(.headline)
            Text("Agent 写操作走后端 API，并记录操作日志。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
