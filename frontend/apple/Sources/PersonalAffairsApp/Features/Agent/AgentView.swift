import Foundation
import PersonalAffairsCore
import SwiftUI

#if os(macOS)
struct AgentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var command = "create_task"
    @State private var argumentsText = "{\n  \"title\": \"Agent 创建的任务\"\n}"
    @State private var dryRun = true
    @State private var responseText = ""
    @State private var confirmationToken = ""
    @State private var provider = "openai"
    @State private var apiKey = ""
    var onSelectAgentLog: (AgentActionLog) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: AppTheme.Spacing.lg)], spacing: AppTheme.Spacing.lg) {
                    SurfaceView {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            agentCommandPanel
                            suggestionChips
                            confirmationPanel
                        }
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        llmKeyPanel
                        toolsPanel
                    }
                }

                SurfaceView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        Text("最近 Agent 操作日志")
                            .font(.headline)
                        if model.agentLogs.isEmpty {
                            EmptyStateInline(title: "暂无日志", message: "Dry Run 和已确认的 App 内操作会出现在这里。")
                        } else {
                            LazyVStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(model.agentLogs) { log in
                                    AgentLogCard(log: log, onSelect: { onSelectAgentLog(log) })
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
        .task {
            await model.run {
                model.agentTools = try await model.agentRepository.tools()
                model.agentLogs = try await model.agentRepository.logs()
                model.llmKey = try await model.agentRepository.llmKey()
            }
        }
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "系统",
            title: "Agent",
            subtitle: "让 App 内 Agent 通过 Dry Run、确认和日志来整理待办、日程、备忘和项目。",
            systemImage: "sparkles"
        )
    }

    private var agentCommandPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("指令编排")
                .font(.headline.weight(.semibold))
            Picker("指令", selection: $command) {
                ForEach(model.agentTools.map(\.name), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            TextField("Arguments JSON", text: $argumentsText, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(7...12)
                .textFieldStyle(.roundedBorder)
            Toggle("Dry Run 预演", isOn: $dryRun)
            HStack {
                Button {
                    execute()
                } label: {
                    Label(dryRun ? "执行预演" : "执行", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await model.run {
                            model.agentLogs = try await model.agentRepository.logs()
                        }
                    }
                } label: {
                    Label("刷新日志", systemImage: "arrow.clockwise")
                }
            }
            if !responseText.isEmpty {
                Text(responseText)
                    .font(.system(.caption, design: .monospaced))
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            }
        }
    }

    private var confirmationPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("操作确认")
                .font(.headline.weight(.semibold))
            if confirmationToken.isEmpty {
                Text("高风险或批量修改在触碰 App 数据前都需要确认。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("这条指令返回了确认令牌。请先核对 Dry Run 摘要，再确认执行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("确认令牌", text: $confirmationToken)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        confirmationToken = ""
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                    Button {
                        confirm()
                    } label: {
                        Label("确认执行", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(confirmationToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .background((confirmationToken.isEmpty ? Color.primary : AppTheme.Colors.warningAccent).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
    }

    private var llmKeyPanel: some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    Text("LLM Key")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    if let key = model.llmKey, key.isActive {
                        PillView(text: "已启用", style: .success)
                    } else {
                        PillView(text: "未配置", style: .warning)
                    }
                }
            if let key = model.llmKey, key.isActive {
                Text("当前：\(key.provider) \(key.keyPreview ?? "")")
                    .foregroundStyle(.secondary)
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
                        await model.run {
                            model.llmKey = try await model.agentRepository.saveLLMKey(provider: provider, apiKey: apiKey)
                            apiKey = ""
                        }
                    }
                }
                .disabled(provider.isEmpty || apiKey.isEmpty)
            }
        }
    }
    }

    private var toolsPanel: some View {
        SurfaceView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("可用工具")
                    .font(.headline.weight(.semibold))
                if model.agentTools.isEmpty {
                    Text("尚未加载工具。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.agentTools.prefix(6)) { tool in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tool.name)
                                .font(.caption.weight(.semibold))
                            Text(tool.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.Spacing.sm)
                        .background(Color.primary.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                    }
                }
            }
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("建议指令")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            HStack {
                suggestion("整理无项目公司待办", command: "list_tasks", arguments: #"{"status":"active","project_scope":"no_project"}"#)
                suggestion("找出最近到期订阅", command: "list_calendar_items", arguments: #"{"item_type":"subscription_expiry"}"#)
                suggestion("今天我可以做什么", command: "list_tasks", arguments: #"{"status":"active","limit":8}"#)
            }
        }
    }

    private func suggestion(_ title: String, command suggestedCommand: String, arguments: String) -> some View {
        Button(title) {
            command = suggestedCommand
            argumentsText = prettyJSON(arguments) ?? arguments
            dryRun = true
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
    }

    private func execute() {
        Task {
            await model.run {
                let arguments = try parseArguments(argumentsText)
                let response = try await model.agentRepository.execute(command: command, arguments: arguments, dryRun: dryRun)
                responseText = render(response)
                if let token = response.confirmationToken {
                    confirmationToken = token
                }
                try await model.loadAllData()
            }
        }
    }

    private func confirm() {
        Task {
            await model.run {
                let response = try await model.agentRepository.confirm(token: confirmationToken)
                responseText = render(response)
                confirmationToken = ""
                try await model.loadAllData()
            }
        }
    }
}

private struct AgentLogCard: View {
    let log: AgentActionLog
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.Colors.agentAccent)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.Colors.agentAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(log.actionType)
                        .font(.callout.weight(.semibold))
                    HStack {
                        PillView(text: log.status, style: log.status == "success" ? .success : .warning)
                        if let targetType = log.targetType {
                            PillView(text: targetType, style: .neutralSubtle)
                        }
                    }
                    if let error = log.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.dangerAccent)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text(log.createdAt.shortDateTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.Spacing.md)
            .background(Color.white.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private func parseArguments(_ text: String) throws -> [String: JSONValue] {
    let data = Data(text.utf8)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dictionary = object as? [String: Any] else { return [:] }
    return dictionary.mapValues { JSONValue.fromAny($0) }
}

private func render(_ response: AgentCommandResponse) -> String {
    var lines = ["状态: \(response.status)"]
    if let reason = response.reason {
        lines.append("原因: \(reason)")
    }
    if let token = response.confirmationToken {
        lines.append("confirmation_token: \(token)")
    }
    if let result = response.result {
        lines.append("结果: \(result)")
    }
    if let wouldExecute = response.wouldExecute {
        lines.append("将执行: \(wouldExecute)")
    }
    return lines.joined(separator: "\n")
}

private func prettyJSON(_ text: String) -> String? {
    guard
        let data = text.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data),
        let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
        let pretty = String(data: prettyData, encoding: .utf8)
    else {
        return nil
    }
    return pretty
}
#endif
