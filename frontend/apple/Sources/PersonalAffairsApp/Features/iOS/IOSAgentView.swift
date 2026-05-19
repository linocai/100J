#if os(iOS)
import Foundation
import PersonalAffairsCore
import SwiftUI

struct IOSAgentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inputText = ""
    @State private var pendingCommand: AgentCommandDraft?
    @State private var pendingConfirmation: AgentConfirmationPrompt?
    @State private var responseText = ""
    @State private var provider = "openai"
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IOSScreenHeader(title: "Agent", subtitle: "App 内事务助理会先生成可审核操作；危险操作由后端要求二次确认。")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }

                Section("指令") {
                    TextField("例如：公司待办 跟进发票 / 明天下午3点公司会议", text: $inputText, axis: .vertical)
                        .lineLimit(2...5)
                    Button {
                        sendMessage()
                    } label: {
                        Label("生成预览", systemImage: "sparkles")
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let pendingCommand {
                    Section("操作预览") {
                        commandSummary(pendingCommand)
                        Button {
                            executePending(dryRun: true)
                        } label: {
                            Label("预演", systemImage: "eye")
                        }
                        Button {
                            executePending(dryRun: false)
                        } label: {
                            Label("确认写入", systemImage: "checkmark.seal")
                        }
                    }
                }

                if let pendingConfirmation {
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
                            self.pendingConfirmation = nil
                            pendingCommand = nil
                            responseText = "已取消这次操作。"
                        } label: {
                            Label("取消", systemImage: "xmark")
                        }
                        Button {
                            confirm(pendingConfirmation)
                        } label: {
                            Label("确认执行", systemImage: "checkmark.seal")
                        }
                    }
                }

                if !responseText.isEmpty {
                    Section("响应") {
                        Text(responseText)
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
                            await model.run {
                                model.llmKey = try await model.agentRepository.saveLLMKey(provider: provider, apiKey: apiKey)
                                apiKey = ""
                            }
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
            .refreshable {
                await reload()
            }
            .overlay { IOSLoadingOverlay() }
            .iosErrorAlert()
            .task {
                await reload()
            }
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

    private func reload() async {
        await model.run {
            model.agentTools = try await model.agentRepository.tools()
            model.agentLogs = try await model.agentRepository.logs()
            model.llmKey = try await model.agentRepository.llmKey()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        guard let intent = CaptureParser.parse(text) else {
            responseText = "我没看懂这句话。可以试试“公司待办 跟进发票”或“明天下午3点公司会议”。"
            pendingCommand = nil
            pendingConfirmation = nil
            return
        }

        guard let draft = AgentNaturalCommandBuilder.build(
            intent: intent,
            personalSpace: model.personalSpace,
            companySpace: model.companySpace
        ) else {
            responseText = "当前空间还没加载完成。请先刷新数据，再试一次。"
            pendingCommand = nil
            pendingConfirmation = nil
            return
        }

        pendingCommand = draft
        pendingConfirmation = nil
        responseText = "已生成可审核操作。"
    }

    private func executePending(dryRun: Bool) {
        guard let pendingCommand else { return }
        Task {
            await model.run {
                let response = try await model.agentRepository.execute(
                    command: pendingCommand.command,
                    arguments: pendingCommand.arguments,
                    dryRun: dryRun
                )
                responseText = renderIOSAgentResponse(response)
                if let prompt = AgentConfirmationPrompt(response: response, draft: pendingCommand) {
                    pendingConfirmation = prompt
                } else if !dryRun {
                    self.pendingCommand = nil
                    pendingConfirmation = nil
                }
                try await model.loadAllData()
            }
        }
    }

    private func confirm(_ prompt: AgentConfirmationPrompt) {
        Task {
            await model.run {
                let response = try await model.agentRepository.confirm(token: prompt.token)
                responseText = renderIOSAgentResponse(response)
                pendingConfirmation = nil
                pendingCommand = nil
                try await model.loadAllData()
            }
        }
    }
}

private func renderIOSAgentResponse(_ response: AgentCommandResponse) -> String {
    var lines = ["状态: \(response.status)"]
    if let reason = response.reason {
        lines.append("原因: \(reason)")
    }
    if let result = response.result {
        lines.append("结果: \(result)")
    }
    if let wouldExecute = response.wouldExecute {
        lines.append("预演: \(wouldExecute)")
    }
    return lines.joined(separator: "\n")
}
#endif
