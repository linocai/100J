import SwiftUI

struct MacSidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: AppSection?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
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
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
            }
            principleCard
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.lg)
        }
        .padding(.top, AppTheme.Spacing.lg)
        .background(AppTheme.Colors.sidebarBackground.opacity(0.54))
    }

    private var brand: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Text("J")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: [AppTheme.Colors.companyAccent, AppTheme.Colors.agentAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("100J")
                    .font(.headline.weight(.semibold))
                Text("Personal Affairs OS")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.isLoading ? AppTheme.Colors.warningAccent : AppTheme.Colors.successAccent)
                        .frame(width: 6, height: 6)
                    Text(model.authMode.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private var principleCard: some View {
        SurfaceView(style: .sidebar, cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Core Rule")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                Text("待办保持弹性；固定时间进入日程；Agent 只做整理和建议。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
    @State private var isHovering = false

    var body: some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: isSelected ? 3 : 0)
                Image(systemName: section.systemImage)
                    .font(.callout.weight(.semibold))
                    .frame(width: isHero ? 30 : 26, height: isHero ? 30 : 26)
                    .foregroundStyle(isSelected ? accent : AppTheme.Colors.secondaryText)
                    .background(accent.opacity(isSelected ? 0.13 : 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font((isHero ? Font.callout.weight(.semibold) : Font.callout.weight(.medium)))
                        .lineLimit(1)
                    if isHero {
                        Text("Command Center")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if let count {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? accent : AppTheme.Colors.tertiaryText)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(AppTheme.Colors.surfaceTinted)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, isHero ? 9 : 7)
            .background(itemBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.sidebarSelectionBorder : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(keyEquivalent, modifiers: .command)
        .accessibilityLabel(section.title)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }

    private var isSelected: Bool {
        selection == section
    }

    private var isHero: Bool {
        section == .today
    }

    private var accent: Color {
        switch section {
        case .today, .agent:
            return AppTheme.Colors.agentAccent
        case .calendar:
            return AppTheme.Colors.calendarAccent
        case .personalTasks, .personalNotes:
            return AppTheme.Colors.personalAccent
        case .companyTasks, .companyProjects:
            return AppTheme.Colors.companyAccent
        case .settings:
            return AppTheme.Colors.tertiaryText
        }
    }

    private var itemBackground: Color {
        if isSelected {
            return AppTheme.Colors.sidebarSelection
        }
        if isHovering {
            return AppTheme.Colors.surfaceTinted
        }
        return .clear
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
