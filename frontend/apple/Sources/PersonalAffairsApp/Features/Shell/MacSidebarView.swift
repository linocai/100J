import PersonalAffairsCore
import SwiftUI

struct MacSidebarView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: AppSection?
    let openSettings: () -> Void
    let switchAccount: () -> Void
    let openAbout: () -> Void

    private let entries: [AppSection] = [.today, .plan, .calendar, .agent]

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section {
                    ForEach(entries) { section in
                        SidebarRow(
                            section: section,
                            count: count(for: section),
                            isActive: selection == section
                        )
                        .tag(Optional(section))
                    }
                } header: {
                    brand
                        .textCase(nil)
                        .padding(.bottom, 6)
                }
            }
            .listStyle(.sidebar)

            Divider()

            avatarMenu
                .padding(12)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Text("J")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("100J")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(model.authMode.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var avatarMenu: some View {
        Menu {
            Button {
                openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            Button {
                switchAccount()
            } label: {
                Label("切换账号", systemImage: "person.crop.circle.badge.arrow.forward")
            }
            Button(role: .destructive) {
                switchAccount()
            } label: {
                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Divider()
            Button {
                openAbout()
            } label: {
                Label("关于 100J", systemImage: "info.circle")
            }
        } label: {
            HStack(spacing: 10) {
                Text(userInitial)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.purple, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private func count(for section: AppSection) -> Int? {
        switch section {
        case .today:
            // 今天要做的：Top 3 焦点 + 今日固定日程；0 时不显示角标
            let n = model.todayViewModel.topThree.count + model.todayViewModel.upcoming.count
            return n > 0 ? n : nil
        case .plan:
            // 仅未完成的弹性待办总数（个人 + 公司 active）
            let n = model.activePersonalTasks.count + model.activeCompanyTasks.count
            return n > 0 ? n : nil
        case .calendar:
            // 今日固定日程数
            let n = CalendarViewState.items(on: Date(), from: model.calendarItems).count
            return n > 0 ? n : nil
        case .agent:
            // 待二次确认的操作数（无则不显示）
            return model.agentReview.pendingConfirmation == nil ? nil : 1
        default:
            return nil
        }
    }

    private var userName: String {
        model.currentUser?.displayName?.trimmedOrNil
            ?? model.currentUser?.email?.trimmedOrNil
            ?? "100J User"
    }

    private var userInitial: String {
        String(userName.prefix(1)).uppercased()
    }

    private var statusLabel: String {
        switch model.syncStatus {
        case .offline:
            return "Offline"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .error:
            return "Needs attention"
        }
    }
}

private struct SidebarRow: View {
    let section: AppSection
    let count: Int?
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? Color.indigo : .secondary)
                .frame(width: 22)
            Text(section.title)
                .font(.callout.weight(isActive ? .semibold : .regular))
            Spacer(minLength: 8)
            if let count {
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 18)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(section.title)\(count.map { "，\($0) 项" } ?? "")")
    }
}
