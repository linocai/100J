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
            return model.todayViewModel.topThree.count
        case .plan:
            return model.planViewModel.personalItems.count
                + model.planViewModel.companyItems.count
                + model.planViewModel.projectItems.count
                + model.planViewModel.noteItems.count
        case .calendar:
            return model.calendarItems.count
        case .agent:
            return model.agentReview.pendingConfirmation == nil ? model.agentLogs.count : 1
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
