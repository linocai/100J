import PersonalAffairsCore
import SwiftUI

/// HTML `.scene-today` 1:1 翻译。三段：Top 3 / 接下来 / Loose Ends + 顶部 metric strip + Agent 建议。
struct TodayScreen: View {
    @EnvironmentObject private var model: AppModel
    var jumpTo: (AppSection) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                header
                metricStrip
                grid
            }
            .padding(.horizontal, AdaptivePageLayout.horizontalPadding)
            .padding(.top, AdaptivePageLayout.topPadding)
            .padding(.bottom, AdaptivePageLayout.bottomPadding)
            .frame(maxWidth: AdaptivePageLayout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(AppTheme.Background.canvas.opacity(0.0))
        .onAppear { model.todayViewModel.refresh() }
        .task { await model.refreshAll() }
    }

    // MARK: Header

    private var header: some View {
        AdaptiveHeroHeader(
            eyebrow: eyebrow,
            title: greeting,
            subtitle: "今天先挑三件事；其余进入 Loose Ends，不会自动排进日程。",
            accent: .orange
        ) {
            HStack(spacing: AppTheme.Spacing.sm) {
                AdaptiveHeroActionButton(
                    fullTitle: "问 Agent",
                    compactTitle: "Agent",
                    systemImage: "sparkles",
                    style: .bordered
                ) {
                    jumpTo(.agent)
                }

                AdaptiveHeroActionButton(
                    fullTitle: "快速捕捉",
                    compactTitle: "捕捉",
                    systemImage: "bolt.fill",
                    style: .prominent(.orange)
                ) {
                    model.universalComposerViewModel.open()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private var eyebrow: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日 · EEEE"
        return f.string(from: Date())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = model.currentUser?.displayName?.nilIfBlank
            ?? model.currentUser?.email?.split(separator: "@").first.map(String.init)
            ?? "你"
        switch hour {
        case 5..<11: return "早上好，\(name)。"
        case 11..<14: return "中午好，\(name)。"
        case 14..<18: return "下午好，\(name)。"
        default: return "晚上好，\(name)。"
        }
    }

    // MARK: Metric strip

    private var metricStrip: some View {
        #if os(iOS)
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ],
            spacing: 1
        ) {
            metric(value: model.activePersonalTasks.count + model.activeCompanyTasks.count,
                   label: "弹性待办", color: .indigo)
            metric(value: model.todayViewModel.upcoming.count, label: "今日日程", color: .orange)
            metric(value: model.todayViewModel.looseEnds.count, label: "Loose Ends", color: .purple)
            metric(value: weekDoneCount(), label: "本周完成", color: .green)
        }
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        #else
        HStack(spacing: 1) {
            metric(value: model.activePersonalTasks.count + model.activeCompanyTasks.count,
                   label: "弹性待办", color: .indigo)
            metric(value: model.todayViewModel.upcoming.count, label: "今日日程", color: .orange)
            metric(value: model.todayViewModel.looseEnds.count, label: "Loose Ends", color: .purple)
            metric(value: weekDoneCount(), label: "本周完成", color: .green)
        }
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        #endif
    }

    private func metric(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background {
            #if os(macOS)
            Rectangle().fill(.regularMaterial)
            #else
            Rectangle().fill(Color(uiColor: .secondarySystemGroupedBackground))
            #endif
        }
    }

    private func weekDoneCount() -> Int {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return (model.personalTasks + model.companyTasks).filter { task in
            task.status == .done && (task.completedAt ?? .distantPast) >= weekAgo
        }.count
    }

    // MARK: Grid

    private var grid: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
            topThreeCard.frame(maxWidth: .infinity)
            upcomingCard.frame(maxWidth: .infinity)
            VStack(spacing: AppTheme.Spacing.lg) {
                looseEndsCard
                agentSuggestionCard
            }
            .frame(maxWidth: .infinity)
        }
        #else
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            topThreeCard
            upcomingCard
            looseEndsCard
            agentSuggestionCard
        }
        #endif
    }

    // MARK: Cards

    private var topThreeCard: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(title: "Top 3 · 今天", meta: "公司 + 个人 合并")
                if model.todayViewModel.topThree.isEmpty {
                    emptyInline(title: "暂无 Top 3", message: "按 ⌘K 捕捉一个真正要推进的事项。")
                } else {
                    ForEach(model.todayViewModel.topThree) { task in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        taskRow(task)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        CardRow {
            Task { await model.toggleTaskDone(task) }
        } content: {
            HStack(spacing: AppTheme.Spacing.md) {
                CheckCircle(done: task.status == .done)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.status == .done)
                        .foregroundStyle(task.status == .done ? .secondary : .primary)
                        .lineLimit(1)
                    Text(taskSubtitle(task))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                StatusPill(text: task.priority.label,
                           style: task.priority.pillStyle,
                           size: .small)
            }
        }
    }

    private func taskSubtitle(_ task: TaskItem) -> String {
        var bits: [String] = []
        if model.personalTasks.contains(where: { $0.id == task.id }) {
            bits.append("个人")
        } else {
            bits.append("公司")
        }
        if let projectName = model.projectName(for: task.projectId) {
            bits.append(projectName)
        }
        if let due = task.dueDate {
            bits.append(due)
        }
        return bits.joined(separator: " · ")
    }

    private var upcomingCard: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(title: "接下来", meta: "今日 \(model.todayViewModel.upcoming.count) 项")
                if model.todayViewModel.upcoming.isEmpty {
                    emptyInline(title: "今天没有固定日程", message: "有具体时间才会进入 Calendar。")
                } else {
                    ForEach(model.todayViewModel.upcoming) { schedule in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        scheduleRow(schedule)
                    }
                }
            }
        }
    }

    private func scheduleRow(_ schedule: TodayScheduleItem) -> some View {
        CardRow {
            HStack(spacing: AppTheme.Spacing.md) {
                Text(schedule.timeLabel)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(width: 56, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.item.title)
                        .font(.body)
                        .lineLimit(1)
                    Text(model.spaceLabel(for: schedule.item.spaceId))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                Image(systemName: "bell")
                    .foregroundStyle(.tertiary)
                    .font(.footnote)
            }
        }
    }

    private var looseEndsCard: some View {
        GlassCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(title: "Loose Ends", meta: "未归类 \(model.todayViewModel.looseEnds.count)")
                if model.todayViewModel.looseEnds.isEmpty {
                    emptyInline(title: "已清空", message: "无项目任务和未转行动的灵感会出现在这里。")
                } else {
                    ForEach(model.todayViewModel.looseEnds.prefix(5)) { loose in
                        Divider().padding(.leading, AppTheme.Spacing.lg)
                        CardRow {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: loose.kind == .task ? "tray" : "lightbulb")
                                    .foregroundStyle(.purple)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loose.title).font(.body).lineLimit(1)
                                    Text(loose.subtitle).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private var agentSuggestionCard: some View {
        GlassCard(tint: .purple, padding: 0) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("Agent 建议")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("\(model.agentLogs.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                if let suggestion = agentSuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Agent 暂时没有建议。可以问它「帮我整理 Loose Ends」。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button {
                    jumpTo(.agent)
                } label: {
                    HStack {
                        Text("打开 Agent")
                        Image(systemName: "arrow.right")
                    }
                    .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.purple)
            }
            .padding(AppTheme.Spacing.lg)
        }
    }

    private var agentSuggestion: String? {
        let loose = model.noProjectCompanyTasks.count
        if loose > 0 {
            return "有 \(loose) 个公司任务没有项目归属，可以让 Agent 一次性整理。"
        }
        let orphanNotes = model.notes.filter { $0.linkedTaskId == nil }.count
        if orphanNotes > 0 {
            return "有 \(orphanNotes) 条灵感未转成行动，Agent 可以帮你转换。"
        }
        return nil
    }

    // MARK: Helpers

    private func cardHeader(title: String, meta: String) -> some View {
        HStack {
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
            Text(meta)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    private func emptyInline(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.callout.weight(.semibold))
            Text(message).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
    }
}

struct CheckCircle: View {
    let done: Bool
    var color: Color = .blue
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(done ? color : Color.secondary.opacity(0.6), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if done {
                Circle().fill(color).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
