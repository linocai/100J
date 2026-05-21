import Foundation
import PersonalAffairsCore
import SwiftUI

#if os(macOS)
struct AgentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
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
            systemImage: "sparkles",
            accent: AppTheme.Colors.agentAccent
        )
    }

    private var commandComposerSurface: some View {
        GroupBox {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Command Composer")
                .font(.headline.weight(.semibold))
            Text("输入指令，或按 ⌘K 快速创建事项。Agent 会先整理成可审核操作。")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)

            HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                TextField("例如：帮我把公司无项目任务整理一下 / 明天下午3点体检 / 灵感 旅行清单", text: $model.agentReview.inputText, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.composeAgentCommand() }

                Button {
                    model.composeAgentCommand()
                } label: {
                    Label("发送", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.agentReview.canCompose)
            }
        }
        }
    }

    private var dryRunPreviewSurface: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    Text("Dry Run Preview")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    if model.agentReview.pendingCommand != nil {
                        Button("预演") {
                            Task { await model.executeAgentCommand(dryRun: true) }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                if let pendingCommand = model.agentReview.pendingCommand {
                    commandSummary(pendingCommand)
                } else {
                    EmptyStateInline(title: "暂无预览", message: "输入一句话后，这里会出现将要执行的操作。")
                }
                if !model.agentReview.responseText.isEmpty {
                    Text(model.agentReview.responseText)
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
        GroupBox {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Action Review")
                .font(.headline.weight(.semibold))

            if let pendingConfirmation = model.agentReview.pendingConfirmation {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(pendingConfirmation.summary)
                        .font(.callout.weight(.semibold))
                    Text(pendingConfirmation.reason)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    PillView(text: "后端要求二次确认", style: .warningSubtle)
                }
                HStack {
                    Button {
                        model.cancelAgentCommand()
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                    Button {
                        Task { await model.confirmAgentCommand() }
                    } label: {
                        Label("确认执行", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let pending = model.agentReview.pendingCommand {
                commandSummary(pending)
                HStack {
                    Button {
                        model.cancelAgentCommand()
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                    Button {
                        Task { await model.executeAgentCommand(dryRun: false) }
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
        GroupBox {
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
        GroupBox {
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

    private func commandSummary(_ command: AgentCommandDraft) -> some View {
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
}
#endif
