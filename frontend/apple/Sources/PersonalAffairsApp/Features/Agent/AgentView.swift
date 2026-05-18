import Foundation
import PersonalAffairsCore
import SwiftUI

#if os(macOS)
struct AgentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var command = "create_task"
    @State private var argumentsText = "{\n  \"title\": \"Agent task\"\n}"
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
                        Text("Recent Agent Logs")
                            .font(.headline)
                        if model.agentLogs.isEmpty {
                            EmptyStateInline(title: "No logs yet", message: "Dry runs and confirmed app-internal actions will appear here.")
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
            eyebrow: "System",
            title: "Agent",
            subtitle: "Let the app organize tasks, calendar items, notes, and projects with dry runs and confirmations.",
            systemImage: "sparkles"
        )
    }

    private var agentCommandPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Command Composer")
                .font(.headline.weight(.semibold))
            Picker("Command", selection: $command) {
                ForEach(model.agentTools.map(\.name), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            TextField("Arguments JSON", text: $argumentsText, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(7...12)
                .textFieldStyle(.roundedBorder)
            Toggle("Dry run", isOn: $dryRun)
            HStack {
                Button {
                    execute()
                } label: {
                    Label(dryRun ? "Run Dry" : "Run", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await model.run {
                            model.agentLogs = try await model.agentRepository.logs()
                        }
                    }
                } label: {
                    Label("Refresh Logs", systemImage: "arrow.clockwise")
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
            Text("Action Review")
                .font(.headline.weight(.semibold))
            if confirmationToken.isEmpty {
                Text("Dangerous or batch changes need confirmation before they touch app data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("This command returned a confirmation token. Review the dry run summary before confirming.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Confirmation token", text: $confirmationToken)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        confirmationToken = ""
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    Button {
                        confirm()
                    } label: {
                        Label("Confirm", systemImage: "checkmark.seal")
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
                        PillView(text: "Active", style: .success)
                    } else {
                        PillView(text: "Missing", style: .warning)
                    }
                }
            if let key = model.llmKey, key.isActive {
                Text("Current: \(key.provider) \(key.keyPreview ?? "")")
                    .foregroundStyle(.secondary)
            } else {
                Text("No key saved")
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Provider", text: $provider)
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
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
                Text("Available Tools")
                    .font(.headline.weight(.semibold))
                if model.agentTools.isEmpty {
                    Text("No tools loaded.")
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
            Text("Suggested Commands")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            HStack {
                suggestion("整理无项目公司待办", command: "organize_company_inbox")
                suggestion("找出最近到期订阅", command: "find_subscription_expiries")
                suggestion("今天我可以做什么", command: "suggest_today_focus")
            }
        }
    }

    private func suggestion(_ title: String, command suggestedCommand: String) -> some View {
        Button(title) {
            command = suggestedCommand
            argumentsText = "{\n  \"dry_run\": true\n}"
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
    var lines = ["status: \(response.status)"]
    if let reason = response.reason {
        lines.append("reason: \(reason)")
    }
    if let token = response.confirmationToken {
        lines.append("confirmation_token: \(token)")
    }
    if let result = response.result {
        lines.append("result: \(result)")
    }
    if let wouldExecute = response.wouldExecute {
        lines.append("would_execute: \(wouldExecute)")
    }
    return lines.joined(separator: "\n")
}
#endif
