import Foundation
import PersonalAffairsCore
import SwiftUI

#if os(macOS)
struct AgentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inputText = ""
    @State private var messages: [AgentChatMessage] = [
        AgentChatMessage(role: .assistant, text: "把一句话发给我。我会先整理成预览，确认后再写入 100J。")
    ]
    @State private var pendingCommand: NaturalAgentCommand?
    @State private var confirmationToken = ""
    var onSelectAgentLog: (AgentActionLog) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                header
                SurfaceView {
                    chatBox
                }
                SurfaceView {
                    confirmationBox
                }
            }
            .padding(AppTheme.Spacing.xl)
        }
    }

    private var header: some View {
        SectionHeaderView(
            eyebrow: "系统",
            title: "Agent",
            subtitle: "一句话整理事务，确认后再写入待办、日程、备忘或项目。",
            systemImage: "sparkles"
        )
    }

    private var chatBox: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("聊天")
                .font(.headline.weight(.semibold))

            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(messages) { message in
                    AgentBubble(message: message)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                TextField("例如：明天下午3点公司会议 / 公司待办 跟进发票 / 灵感 旅行清单", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
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

    private var confirmationBox: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("确认")
                .font(.headline.weight(.semibold))

            if !confirmationToken.isEmpty {
                Text("这条操作被后端标记为高风险，需要二次确认。")
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                HStack {
                    Button {
                        confirmationToken = ""
                        pendingCommand = nil
                        messages.append(.init(role: .assistant, text: "已取消这次操作。"))
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
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack {
                        PillView(text: pending.intent.target.label, style: .agent)
                        PillView(
                            text: pending.intent.calendarSpace.label,
                            style: pending.intent.calendarSpace == .personal ? .personal : .company
                        )
                    }
                    Text(pending.summary)
                        .font(.callout.weight(.semibold))
                    Text("确认后会写入 100J，并保留 Agent 操作记录。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                HStack {
                    Button {
                        pendingCommand = nil
                        messages.append(.init(role: .assistant, text: "已取消这次操作。"))
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(.init(role: .user, text: text))
        inputText = ""

        guard let intent = CaptureParser.parse(text) else {
            messages.append(.init(role: .assistant, text: "我没看懂这句话。可以试试“公司待办 跟进发票”或“明天下午3点公司会议”。"))
            pendingCommand = nil
            return
        }

        guard let built = buildNaturalCommand(intent) else {
            messages.append(.init(role: .assistant, text: "当前空间还没加载完成。请先刷新数据，再试一次。"))
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
        messages.append(.init(role: .assistant, text: "我会这样处理：\(command.summary)。确认后写入。"))
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
                messages.append(.init(role: .assistant, text: render(response)))
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
                messages.append(.init(role: .assistant, text: render(response)))
                confirmationToken = ""
                pendingCommand = nil
                try await model.loadAllData()
            }
        }
    }
}

private struct AgentChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

private struct AgentBubble: View {
    let message: AgentChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            Text(message.text)
                .font(.callout)
                .foregroundStyle(message.role == .user ? .white : AppTheme.Colors.primaryText)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, 10)
                .background(message.role == .user ? AppTheme.Colors.agentAccent : Color.white.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                .frame(maxWidth: 640, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity)
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
