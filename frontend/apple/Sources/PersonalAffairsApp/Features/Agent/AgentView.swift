import Foundation
import PersonalAffairsCore
import SwiftUI

#if os(macOS)
struct AgentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @State private var inputText = ""
    @State private var pendingCommand: NaturalAgentCommand?
    @State private var confirmationToken = ""
    @State private var responseText = ""
    var onSelectAgentLog: (AgentActionLog) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                if layout.usesWideColumns {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            commandComposerSurface
                            dryRunPreviewSurface
                            actionReviewSurface
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                            agentStatusSurface
                            recentActionLogsSurface
                        }
                        .frame(width: min(360, max(300, layout.centerWidth * 0.34)))
                    }
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        commandComposerSurface
                        dryRunPreviewSurface
                        actionReviewSurface
                        agentStatusSurface
                        recentActionLogsSurface
                    }
                }
            }
            .padding(layout.pagePadding)
        }
    }

    private var header: some View {
        SectionHeaderView(
            style: .hero,
            eyebrow: "系统",
            title: "Agent",
            subtitle: "事务助理负责解析、预演和审核；危险操作必须确认。",
            systemImage: "sparkles"
        )
    }

    private var commandComposerSurface: some View {
        SurfaceView(style: .elevated) {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Command Composer")
                .font(.headline.weight(.semibold))
            Text("输入指令，或按 ⌘K 快速创建事项。Agent 会先整理成可审核操作。")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                TextField("例如：帮我把公司无项目任务整理一下 / 明天下午3点体检 / 灵感 旅行清单", text: $inputText, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(sendMessage)

                Button {
                    sendMessage()
                } label: {
                    Label("发送", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        }
    }

    private var dryRunPreviewSurface: some View {
        SurfaceView(style: .subtle) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    Text("Dry Run Preview")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    if pendingCommand != nil {
                        Button("预演") { executePending(dryRun: true) }
                            .font(.caption.weight(.semibold))
                    }
                }
                if let pendingCommand {
                    commandSummary(pendingCommand)
                } else {
                    EmptyStateInline(title: "暂无预览", message: "输入一句话后，这里会出现将要执行的操作。")
                }
                if !responseText.isEmpty {
                    Text(responseText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Colors.surfaceTinted)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                }
            }
        }
    }

    private var actionReviewSurface: some View {
        SurfaceView(style: confirmationToken.isEmpty ? .base : .warning) {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Action Review")
                .font(.headline.weight(.semibold))

            if !confirmationToken.isEmpty {
                Text("这条操作被后端标记为高风险，需要二次确认。")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                HStack {
                    Button {
                        confirmationToken = ""
                        pendingCommand = nil
                        responseText = "已取消这次操作。"
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                    Button {
                        confirmBackendToken()
                    } label: {
                        Label("确认执行", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let pending = pendingCommand {
                commandSummary(pending)
                HStack {
                    Button {
                        pendingCommand = nil
                        responseText = "已取消这次操作。"
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                    Button {
                        executePending(dryRun: false)
                    } label: {
                        Label("确认写入", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("还没有待确认的操作。发送一句话后，这里会出现结构化预览。")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var agentStatusSurface: some View {
        SurfaceView(style: .tinted(.agent)) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Label("Agent Layer", systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                suggestionRow("\(model.noProjectCompanyTasks.count) 个公司任务没有项目归属")
                suggestionRow("\(model.notes.filter { $0.linkedTaskId == nil }.count) 条灵感可生成行动候选")
                if let key = model.llmKey, key.isActive {
                    PillView(text: "LLM \(key.provider)", style: .success)
                } else {
                    PillView(text: "LLM Key 在 Settings 管理", style: .warningSubtle)
                }
            }
        }
    }

    private var recentActionLogsSurface: some View {
        SurfaceView(style: .inspector) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Recent Agent Actions")
                    .font(.headline.weight(.semibold))
                if model.agentLogs.isEmpty {
                    EmptyStateInline(title: "暂无操作记录", message: "预演或确认写入后会出现在这里。")
                } else {
                    ForEach(model.agentLogs.prefix(6)) { log in
                        Button {
                            onSelectAgentLog(log)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(log.actionType)
                                        .font(.caption.weight(.semibold))
                                    Text(log.createdAt.shortDateTime)
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                                }
                                Spacer()
                                PillView(text: log.status, style: log.status == "success" ? .success : .warning, size: .small)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func commandSummary(_ command: NaturalAgentCommand) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                PillView(text: command.intent.target.label, style: .agent)
                PillView(
                    text: command.intent.calendarSpace.label,
                    style: command.intent.calendarSpace == .personal ? .personal : .company
                )
                PillView(text: "Needs approve", style: .warningSubtle)
            }
            Text(command.summary)
                .font(.callout.weight(.semibold))
            Text("No deletion. No calendar changes unless the command is a fixed schedule. Backend keeps an Agent action log.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func suggestionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Circle()
                .fill(AppTheme.Colors.agentAccent)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        guard let intent = CaptureParser.parse(text) else {
            responseText = "我没看懂这句话。可以试试“公司待办 跟进发票”或“明天下午3点公司会议”。"
            pendingCommand = nil
            return
        }

        guard let built = buildNaturalCommand(intent) else {
            responseText = "当前空间还没加载完成。请先刷新数据，再试一次。"
            pendingCommand = nil
            return
        }

        let command = NaturalAgentCommand(
            intent: intent,
            command: built.command,
            arguments: built.arguments,
            summary: built.summary
        )
        pendingCommand = command
        confirmationToken = ""
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
                responseText = render(response)
                if let token = response.confirmationToken {
                    confirmationToken = token
                } else if !dryRun {
                    self.pendingCommand = nil
                }
                try await model.loadAllData()
            }
        }
    }

    private func confirmBackendToken() {
        Task {
            await model.run {
                let response = try await model.agentRepository.confirm(token: confirmationToken)
                responseText = render(response)
                confirmationToken = ""
                pendingCommand = nil
                try await model.loadAllData()
            }
        }
    }
}

private struct NaturalAgentCommand {
    let intent: ParsedCaptureIntent
    let command: String
    let arguments: [String: JSONValue]
    let summary: String
}

private extension ParsedCaptureTarget {
    var label: String {
        switch self {
        case .personalTask: return "个人待办"
        case .companyTask: return "公司待办"
        case .fixedCalendar: return "固定日程"
        case .personalNote: return "个人备忘"
        case .companyProject: return "公司项目"
        }
    }
}

private extension AgentView {
    func buildNaturalCommand(_ intent: ParsedCaptureIntent) -> (command: String, arguments: [String: JSONValue], summary: String)? {
        switch intent.target {
        case .personalTask:
            guard let space = model.personalSpace else { return nil }
            return ("create_task", baseTaskArguments(spaceId: space.id, intent: intent), "创建个人待办：\(intent.title)")
        case .companyTask:
            guard let space = model.companySpace else { return nil }
            return ("create_task", baseTaskArguments(spaceId: space.id, intent: intent), "创建公司待办：\(intent.title)")
        case .fixedCalendar:
            let targetSpace = intent.calendarSpace == .personal ? model.personalSpace : model.companySpace
            guard let space = targetSpace else { return nil }
            var arguments: [String: JSONValue] = [
                "space_id": .string(space.id),
                "title": .string(intent.title),
                "description": .string(intent.description ?? intent.title),
                "type": .string(intent.calendarType.rawValue),
                "all_day": .bool(intent.allDay),
                "timezone": .string(TimeZone.current.identifier),
                "recurrence": .string(intent.recurrence.rawValue)
            ]
            if intent.allDay {
                arguments["start_date"] = .string(intent.startDate ?? Date().dayKey)
            } else if let startAt = intent.startAt {
                arguments["start_at"] = .string(Self.isoFormatter.string(from: startAt))
            }
            return ("create_calendar_item", arguments, "创建\(intent.calendarSpace.label)固定日程：\(intent.title)")
        case .personalNote:
            guard let space = model.personalSpace else { return nil }
            return (
                "create_note",
                [
                    "space_id": .string(space.id),
                    "title": .string(intent.title),
                    "body": .string(intent.description ?? intent.title),
                    "type": .string(intent.noteType.rawValue)
                ],
                "创建个人备忘：\(intent.title)"
            )
        case .companyProject:
            guard let space = model.companySpace else { return nil }
            return (
                "create_project",
                [
                    "space_id": .string(space.id),
                    "name": .string(intent.title),
                    "description": .string(intent.description ?? "")
                ],
                "创建公司项目：\(intent.title)"
            )
        }
    }

    func baseTaskArguments(spaceId: String, intent: ParsedCaptureIntent) -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [
            "space_id": .string(spaceId),
            "title": .string(intent.title),
            "priority": .string(intent.priority.rawValue)
        ]
        if let description = intent.description {
            arguments["description"] = .string(description)
        }
        if let dueDate = intent.dueDate {
            arguments["due_date"] = .string(dueDate)
        }
        return arguments
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private func render(_ response: AgentCommandResponse) -> String {
    if let reason = response.reason {
        return "状态：\(response.status)\n原因：\(reason)"
    }
    if let result = response.result {
        return "状态：\(response.status)\n结果：\(result)"
    }
    if let wouldExecute = response.wouldExecute {
        return "预演：\(wouldExecute)"
    }
    return "状态：\(response.status)"
}
#endif
