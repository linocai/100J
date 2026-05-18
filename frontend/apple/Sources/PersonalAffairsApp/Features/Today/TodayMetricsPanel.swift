import SwiftUI

struct TodayMetricsPanel: View {
    let personalCount: Int
    let companyCount: Int
    let fixedCount: Int
    let looseCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
            MetricCardView(
                title: "Personal active",
                value: "\(personalCount)",
                caption: "Flexible tasks",
                style: .personal,
                systemImage: "checklist"
            )
            MetricCardView(
                title: "Company active",
                value: "\(companyCount)",
                caption: "Project and inbox",
                style: .company,
                systemImage: "rectangle.3.group"
            )
            MetricCardView(
                title: "Fixed schedule",
                value: "\(fixedCount)",
                caption: "Today + 7 days",
                style: .warning,
                systemImage: "calendar"
            )
            MetricCardView(
                title: "No Project Inbox",
                value: "\(looseCount)",
                caption: "Company loose ends",
                style: .agent,
                systemImage: "tray"
            )
        }
    }
}
