import PersonalAffairsCore
import SwiftUI

struct FixedSchedulePanel: View {
    @EnvironmentObject private var model: AppModel
    var selection: InspectorSelection?
    let todayItems: [CalendarItem]
    let upcomingItems: [CalendarItem]
    let selectCalendarItem: (CalendarItem) -> Void
    let showMore: () -> Void

    var body: some View {
        SurfaceView(style: .elevated) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("固定日程")
                            .font(.headline.weight(.semibold))
                        Text("这里只放约会、纪念日、订阅到期、截止日和提醒。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("日程", action: showMore)
                        .font(.caption.weight(.semibold))
                }

                allDayGroup(items: todayItems.filter(\.allDay))
                timelineGroup("今天", items: todayItems.filter { !$0.allDay })
                timelineGroup("接下来", items: Array(upcomingItems.prefix(6)))
            }
        }
    }

    private func allDayGroup(items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("All-day")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
            if items.isEmpty {
                Text("今天没有全天固定事项。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            } else {
                ForEach(items) { item in
                    timelineRow(item, label: "全天")
                }
            }
        }
    }

    private func timelineGroup(_ title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)

            if items.isEmpty {
                Text(title == "今天" ? "今天没有固定日程。" : "未来一周没有固定日程。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(items) { item in
                        timelineRow(item, label: timeLabel(item))
                    }
                }
            }
        }
    }

    private func timelineRow(_ item: CalendarItem, label: String) -> some View {
        Button {
            selectCalendarItem(item)
        } label: {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.type.pillStyle.color)
                    .frame(width: 58, alignment: .leading)
                VStack(spacing: 0) {
                    Circle()
                        .fill(item.type.pillStyle.color)
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(AppTheme.Colors.hairline)
                        .frame(width: 1)
                }
                .frame(minHeight: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(2)
                    HStack(spacing: 5) {
                        PillView(text: item.type.label, style: item.type.pillStyle, size: .small)
                        PillView(text: model.spaceLabel(for: item.spaceId), style: spaceStyle(item.spaceId), size: .small)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(selection == .calendarItem(item.id) ? item.type.pillStyle.color.opacity(0.12) : AppTheme.Colors.surfaceBase)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func timeLabel(_ item: CalendarItem) -> String {
        if item.allDay { return "全天" }
        return item.startAt?.compactTime ?? "定时"
    }

    private func spaceStyle(_ spaceId: String) -> PillStyle {
        model.spaces.first { $0.id == spaceId }?.type == .personal ? .personal : .company
    }

    private func delete(_ item: CalendarItem) {
        Task {
            await model.deleteCalendarItem(item)
        }
    }
}
