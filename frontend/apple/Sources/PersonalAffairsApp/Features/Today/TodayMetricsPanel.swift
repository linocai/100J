import SwiftUI

struct TodayMetricsPanel: View {
    let personalCount: Int
    let companyCount: Int
    let fixedCount: Int
    let looseCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
            MetricCardView(
                title: "个人进行中",
                value: "\(personalCount)",
                caption: "弹性待办",
                style: .personal,
                systemImage: "checklist"
            )
            MetricCardView(
                title: "公司进行中",
                value: "\(companyCount)",
                caption: "项目与收件箱",
                style: .company,
                systemImage: "rectangle.3.group"
            )
            MetricCardView(
                title: "固定日程",
                value: "\(fixedCount)",
                caption: "今天 + 7 天",
                style: .warning,
                systemImage: "calendar"
            )
            MetricCardView(
                title: "无项目收件箱",
                value: "\(looseCount)",
                caption: "公司散项",
                style: .agent,
                systemImage: "tray"
            )
        }
    }
}
