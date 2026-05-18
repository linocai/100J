import PersonalAffairsCore
import SwiftUI

struct FixedSchedulePanel: View {
    @EnvironmentObject private var model: AppModel
    let todayItems: [CalendarItem]
    let upcomingItems: [CalendarItem]
    let selectCalendarItem: (CalendarItem) -> Void
    let showMore: () -> Void

    var body: some View {
        SurfaceView {
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

                fixedGroup("今天", items: todayItems)
                fixedGroup("接下来", items: Array(upcomingItems.prefix(6)))
            }
        }
    }

    private func fixedGroup(_ title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)

            if items.isEmpty {
                Text(title == "今天" ? "今天没有固定日程。" : "未来一周没有固定日程。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(items) { item in
                        CalendarEventCardView(
                            item: item,
                            spaceName: model.spaceLabel(for: item.spaceId),
                            spaceStyle: spaceStyle(item.spaceId),
                            projectName: model.projectName(for: item.projectId),
                            compact: true,
                            onSelect: { selectCalendarItem(item) },
                            onDelete: { delete(item) }
                        )
                    }
                }
            }
        }
    }

    private func spaceStyle(_ spaceId: String) -> PillStyle {
        model.spaces.first { $0.id == spaceId }?.type == .personal ? .personal : .company
    }

    private func delete(_ item: CalendarItem) {
        Task {
            await model.run {
                _ = try await model.calendarRepository.delete(id: item.id)
                try await model.loadAllData()
            }
        }
    }
}
