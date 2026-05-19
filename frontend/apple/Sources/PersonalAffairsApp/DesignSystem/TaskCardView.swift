import PersonalAffairsCore
import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    let projectName: String?
    let spaceStyle: PillStyle
    let spaceLabel: String
    var isSelected = false
    var compact = false
    let onSelect: () -> Void
    let onComplete: () -> Void
    let onReopen: () -> Void
    let onArchive: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Button(action: task.status == .done ? onReopen : onComplete) {
                    Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.status == .done ? AppTheme.Colors.successAccent : AppTheme.Colors.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(task.status == .done ? "重新打开任务" : "完成任务")
                .accessibilityLabel(task.status == .done ? "重新打开 \(task.title)" : "完成 \(task.title)")

                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    Text(task.title)
                        .font(.callout.weight(.semibold))
                        .strikethrough(task.status == .done)
                        .foregroundStyle(task.status == .done ? AppTheme.Colors.secondaryText : AppTheme.Colors.primaryText)
                        .lineLimit(2)

                    if let description = task.description?.trimmedOrNil, !compact {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(2)
                    }

                    WrappingHStack(spacing: 6, rowSpacing: 5) {
                        PillView(text: task.priority.label, style: task.priority.pillStyle)
                        if let dueDate = task.dueDate {
                            PillView(text: dueLabel(dueDate), style: duePillStyle(dueDate), systemImage: "calendar.badge.clock")
                        }
                        if let projectName {
                            PillView(text: projectName, style: .company, systemImage: "folder")
                        } else if spaceStyle == .company {
                            PillView(text: "No Project", style: .warningSubtle, systemImage: "tray")
                        } else {
                            PillView(text: spaceLabel, style: spaceStyle)
                        }
                        if task.source == "agent" {
                            PillView(text: "Agent", style: .agent, systemImage: "sparkles")
                        } else if task.status != .active {
                            PillView(text: task.status.label, style: task.status == .done ? .success : .neutralSubtle)
                        }
                    }
                }

                Spacer(minLength: AppTheme.Spacing.md)

                Button(action: onArchive) {
                    Image(systemName: "archivebox")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("归档")
                .opacity(isHovering || isSelected ? 1 : 0.58)
            }
            .padding(compact ? 10 : 12)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(selectionColor)
                    .frame(width: isSelected ? 3 : 0)
                    .padding(.vertical, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? selectionColor.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .opacity(task.status == .done ? 0.74 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title)，\(task.status.label)任务")
    }

    private var cardBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(selectionColor.opacity(0.12))
        }
        if isHovering {
            return AnyShapeStyle(AppTheme.Colors.surfaceElevated)
        }
        return AnyShapeStyle(AppTheme.Colors.surfaceBase)
    }

    private var selectionColor: Color {
        spaceStyle == .personal ? AppTheme.Colors.personalAccent : AppTheme.Colors.companyAccent
    }

    private func dueLabel(_ value: String) -> String {
        guard let date = parsedDateOnly(value) else { return "截止 \(value)" }
        if Calendar.current.isDateInToday(date) { return "今天截止" }
        if date < Calendar.current.startOfDay(for: Date()) { return "已逾期" }
        return "截止 \(value)"
    }

    private func duePillStyle(_ value: String) -> PillStyle {
        guard let date = parsedDateOnly(value) else { return .warningSubtle }
        let today = Calendar.current.startOfDay(for: Date())
        let soon = Calendar.current.date(byAdding: .day, value: 2, to: today) ?? today
        if date < today { return .danger }
        if date <= soon { return .warning }
        return .warningSubtle
    }
}

struct TaskCardList<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVStack(spacing: AppTheme.Spacing.sm) {
            content
        }
    }
}
