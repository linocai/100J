import PersonalAffairsCore
import SwiftUI

/// HTML `.scene-agent` 1:1 翻译。聊天气泡 + 待确认卡片 + 最近写入 + LLM Key 状态。
struct AgentScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var commandInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                header
                grid
            }
            .padding(.horizontal, AdaptivePageLayout.horizontalPadding)
            .padding(.top, AdaptivePageLayout.topPadding)
            .padding(.bottom, AdaptivePageLayout.bottomPadding)
            .frame(maxWidth: AdaptivePageLayout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .task { await model.reloadAgentSupport() }
    }

    private var header: some View {
        AdaptiveHeroHeader(
            eyebrow: "系统",
            title: "Agent",
            subtitle: "事务助理负责解析、预演和审核。写操作走二次确认，所有动作进入 action log。",
            accent: .purple
        ) {
            llmStatus
        }
    }

    private var llmStatus: some View {
        Group {
            if let key = model.llmKey, key.isActive {
                StatusPill(text: "LLM · \(key.provider)", color: .green, systemImage: "checkmark.seal.fill")
            } else {
                StatusPill(text: "LLM Key 未配置", color: .orange, systemImage: "exclamationmark.triangle.fill")
            }
        }
    }

    private var grid: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
            conversationCard.frame(maxWidth: .infinity)
            actionLogCard.frame(maxWidth: 360)
        }
        #else
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            conversationCard
            actionLogCard
        }
        #endif
    }

    private var conversationCard: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: "对话", subtitle: nil, systemImage: "sparkles", accent: .purple)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    if let response = model.agentReview.responseText.nilIfBlank {
                        ChatBubble(role: .bot, text: response)
                    } else if model.agentReview.pendingCommand == nil {
                        Text("还没有对话。试试「帮我把无项目公司任务整理出来」。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let draft = model.agentReview.pendingCommand {
                        PendingDraftView(draft: draft) {
                            Task { await model.executeAgentCommand(dryRun: false) }
                        } cancel: {
                            model.cancelAgentCommand()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                Divider()

                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "mic")
                        .foregroundStyle(.secondary)
                    TextField("一句话指令，Agent 会先解析为可审核的操作…",
                              text: $commandInput,
                              axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .onSubmit(submit)
                    Button(action: submit) {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLoading)
                }
                .padding(AppTheme.Spacing.md)
            }
        }
    }

    private var actionLogCard: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    InlineSectionLabel(title: "最近写入", subtitle: model.agentLogs.isEmpty ? "暂无" : "\(model.agentLogs.count) 条")
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.md)

                if model.agentLogs.isEmpty {
                    Text("Agent 写入会出现在这里。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(AppTheme.Spacing.lg)
                } else {
                    ForEach(model.agentLogs.prefix(8)) { log in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        CardRow {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.actionType)
                                        .font(.callout.weight(.medium))
                                    Text(log.createdAt.shortDateTime)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 0)
                                StatusPill(text: log.status,
                                           color: log.status == "success" ? .green : .orange,
                                           size: .small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func submit() {
        let text = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        commandInput = ""
        model.agentReview.inputText = text
        model.composeAgentCommand()
    }
}

private struct ChatBubble: View {
    enum Role { case user, bot }
    let role: Role
    let text: String

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 36) }
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .foregroundStyle(role == .user ? .white : .primary)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    role == .user ? Color.purple : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            if role == .bot { Spacer(minLength: 36) }
        }
    }
}

private struct PendingDraftView: View {
    let draft: AgentCommandDraft
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: 6) {
                StatusPill(text: draft.intent.target.label, color: .indigo, size: .small)
                StatusPill(text: "Needs approve", color: .orange, size: .small)
            }
            Text(draft.summary)
                .font(.callout.weight(.semibold))
            HStack(spacing: AppTheme.Spacing.sm) {
                Button("取消", action: cancel)
                    .buttonStyle(.bordered)
                Button {
                    confirm()
                } label: {
                    Label("确认写入", systemImage: "checkmark.seal")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 0.5)
        )
    }
}
