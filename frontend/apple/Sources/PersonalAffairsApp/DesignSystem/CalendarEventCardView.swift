import PersonalAffairsCore
import SwiftUI

struct CalendarEventCardView: View {
    let item: CalendarItem
    let spaceName: String
    let spaceStyle: PillStyle
    let projectName: String?
    var isSelected = false
    var compact = false
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: item.type.systemImage)
                    .font(.headline)
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(timeLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                        Spacer(minLength: AppTheme.Spacing.sm)
                        if let recurrence = item.recurrence, recurrence != .none {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                        }
                    }

                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(2)

                    if let description = item.description?.trimmedOrNil, !compact {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(2)
                    }

                    WrappingHStack(spacing: 6, rowSpacing: 5) {
                        PillView(text: spaceName, style: spaceStyle)
                        PillView(text: item.type.label, style: item.type.pillStyle)
                        if let projectName {
                            PillView(text: projectName, style: .company, systemImage: "folder")
                        }
                        if item.source == "agent" {
                            PillView(text: "Agent", style: .agent, systemImage: "sparkles")
                        }
                    }
                }

                Spacer(minLength: AppTheme.Spacing.md)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("删除固定日程")
                .opacity(isHovering || isSelected ? 1 : 0.58)
            }
            .padding(compact ? 10 : 12)
            .background(isSelected ? accent.opacity(0.12) : (isHovering ? AppTheme.Colors.surfaceElevated : AppTheme.Colors.surfaceBase))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4)
                    .padding(.vertical, 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)，固定日程")
    }

    private var accent: Color {
        switch item.type {
        case .subscriptionExpiry, .anniversary:
            return AppTheme.Colors.warningAccent
        case .deadline:
            return AppTheme.Colors.dangerAccent
        default:
            return spaceStyle == .personal ? AppTheme.Colors.personalAccent : AppTheme.Colors.companyAccent
        }
    }

    private var timeLabel: String {
        if item.allDay {
            return item.startDate ?? "全天"
        }
        return item.startAt?.shortDateTime ?? "定时"
    }
}
