#if canImport(WidgetKit)
import PersonalAffairsCore
import SwiftUI
import WidgetKit

@main
struct OneHundredJWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayFocusWidget()
        TodayAgendaWidget()
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = WidgetEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayFocusWidget: Widget {
    let kind = "OneHundredJTodayFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            TodayFocusWidgetView(entry: entry)
        }
        .configurationDisplayName("100J Top 3")
        .description("显示今天最重要的三件事。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayAgendaWidget: Widget {
    let kind = "OneHundredJTodayAgendaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            TodayAgendaWidgetView(entry: entry)
        }
        .configurationDisplayName("100J Agenda")
        .description("显示接下来三条固定日程。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayFocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(title: "Top 3", systemImage: "sun.max")

            if entry.snapshot.topThree.isEmpty {
                emptyText("暂无焦点事项")
            } else {
                ForEach(prefix(entry.snapshot.topThree)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                        if family != .systemSmall {
                            Text(item.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .widgetContainerBackground()
        .padding()
    }

    private func prefix(_ items: [WidgetTaskSnapshot]) -> [WidgetTaskSnapshot] {
        Array(items.prefix(family == .systemSmall ? 2 : 3))
    }
}

struct TodayAgendaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(title: "Agenda", systemImage: "calendar")

            if entry.snapshot.upcoming.isEmpty {
                emptyText("暂无固定日程")
            } else {
                ForEach(prefix(entry.snapshot.upcoming)) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.timeLabel)
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(width: family == .systemSmall ? 36 : 42, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            if family != .systemSmall {
                                Text(item.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .widgetContainerBackground()
        .padding()
    }

    private func prefix(_ items: [WidgetCalendarSnapshot]) -> [WidgetCalendarSnapshot] {
        Array(items.prefix(family == .systemSmall ? 2 : 3))
    }
}

private func widgetHeader(title: String, systemImage: String) -> some View {
    HStack(spacing: 5) {
        Image(systemName: systemImage)
            .foregroundStyle(.blue)
        Text(title)
            .font(.caption.weight(.bold))
        Spacer(minLength: 0)
    }
}

private func emptyText(_ text: String) -> some View {
    Text(text)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
}

private extension View {
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            containerBackground(.background, for: .widget)
        } else {
            background(Color.clear)
        }
    }
}
#else
@main
struct OneHundredJWidgetsFallback {
    static func main() {}
}
#endif
