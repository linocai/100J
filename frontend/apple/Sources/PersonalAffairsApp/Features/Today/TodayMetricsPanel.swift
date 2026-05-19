import SwiftUI

struct TodayMetricsPanel: View {
    let personalCount: Int
    let companyCount: Int
    let fixedCount: Int
    let looseCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: AppTheme.Spacing.sm)], spacing: AppTheme.Spacing.sm) {
            MetricCardView(
                title: "Focus Tasks",
                value: "\(personalCount)",
                caption: "个人弹性",
                style: .personal,
                systemImage: "checklist"
            )
            MetricCardView(
                title: "Company",
                value: "\(companyCount)",
                caption: "项目与收件箱",
                style: .company,
                systemImage: "rectangle.3.group"
            )
            MetricCardView(
                title: "Fixed Events",
                value: "\(fixedCount)",
                caption: "今天 + 7 天",
                style: .calendar,
                systemImage: "calendar"
            )
            MetricCardView(
                title: "Company Inbox",
                value: "\(looseCount)",
                caption: "公司散项",
                style: .warning,
                systemImage: "tray"
            )
        }
    }
}
