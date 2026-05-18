import SwiftUI

struct MacSidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: AppSection?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            brand
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    sidebarGroup("焦点") {
                        SidebarButton(section: .today, count: todayCount, selection: $selection)
                        SidebarButton(section: .calendar, count: fixedCount, selection: $selection)
                    }
                    sidebarGroup("个人") {
                        SidebarButton(section: .personalTasks, count: model.activePersonalTasks.count, selection: $selection)
                        SidebarButton(section: .personalNotes, count: model.notes.count, selection: $selection)
                    }
                    sidebarGroup("公司") {
                        SidebarButton(section: .companyTasks, count: model.activeCompanyTasks.count, selection: $selection)
                        SidebarButton(section: .companyProjects, count: model.projects.count, selection: $selection)
                    }
                    sidebarGroup("系统") {
                        SidebarButton(section: .agent, count: model.agentLogs.count, selection: $selection)
                        SidebarButton(section: .settings, count: nil, selection: $selection)
                    }
                    principleCard
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
        }
        .padding(.top, AppTheme.Spacing.lg)
        .background(.thinMaterial)
    }

    private var brand: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text("J")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [AppTheme.Colors.companyAccent, AppTheme.Colors.agentAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("100J")
                    .font(.headline.weight(.semibold))
                Text("个人事务操作台")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private var principleCard: some View {
        SurfaceView(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("核心规则")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                Text("待办保持弹性；固定时间进入日程；灵感先留在备忘，确认后再转成任务。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func sidebarGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
                .padding(.horizontal, AppTheme.Spacing.sm)
            content()
        }
    }

    private var todayCount: Int {
        min(model.activePersonalTasks.count, 4) + min(model.activeCompanyTasks.count, 4) + fixedCount
    }

    private var fixedCount: Int {
        model.calendarItems.count
    }
}

private struct SidebarButton: View {
    let section: AppSection
    let count: Int?
    @Binding var selection: AppSection?

    var body: some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: section.systemImage)
                    .font(.callout.weight(.semibold))
                    .frame(width: 25, height: 25)
                    .foregroundStyle(isSelected ? AppTheme.Colors.companyAccent : AppTheme.Colors.secondaryText)
                    .background((isSelected ? AppTheme.Colors.companyAccent : Color.primary).opacity(isSelected ? 0.12 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(section.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let count {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? AppTheme.Colors.companyAccent : AppTheme.Colors.tertiaryText)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Color.primary.opacity(isSelected ? 0.00 : 0.06))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, 7)
            .background(isSelected ? Color.white.opacity(0.72) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(keyEquivalent, modifiers: .command)
        .accessibilityLabel(section.title)
    }

    private var isSelected: Bool {
        selection == section
    }

    private var keyEquivalent: KeyEquivalent {
        switch section {
        case .today: return "1"
        case .personalTasks: return "2"
        case .personalNotes: return "3"
        case .companyTasks: return "4"
        case .calendar: return "5"
        case .agent: return "6"
        case .companyProjects: return "7"
        case .settings: return "8"
        }
    }
}
