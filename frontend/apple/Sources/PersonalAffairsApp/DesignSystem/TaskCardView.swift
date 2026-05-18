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
                .help(task.status == .done ? "Reopen task" : "Complete task")
                .accessibilityLabel(task.status == .done ? "Reopen \(task.title)" : "Complete \(task.title)")

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

                    HStack(spacing: 6) {
                        PillView(text: task.priority.label, style: task.priority.pillStyle)
                        PillView(text: task.status.label, style: task.status == .done ? .success : .neutralSubtle)
                        PillView(text: spaceLabel, style: spaceStyle)
                        if let dueDate = task.dueDate {
                            PillView(text: "Due \(dueDate)", style: .warningSubtle, systemImage: "calendar.badge.clock")
                        }
                        if let projectName {
                            PillView(text: projectName, style: .company, systemImage: "folder")
                        }
                        if task.source == "agent" {
                            PillView(text: "Agent", style: .agent, systemImage: "sparkles")
                        }
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                Button(action: onArchive) {
                    Image(systemName: "archivebox")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Archive")
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
        .accessibilityLabel("\(task.title), \(task.status.label) task")
    }

    private var cardBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(selectionColor.opacity(0.12))
        }
        if isHovering {
            return AnyShapeStyle(Color.white.opacity(0.72))
        }
        return AnyShapeStyle(Color.white.opacity(0.54))
    }

    private var selectionColor: Color {
        spaceStyle == .personal ? AppTheme.Colors.personalAccent : AppTheme.Colors.companyAccent
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
