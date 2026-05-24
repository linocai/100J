#if os(macOS)
import PersonalAffairsCore
import SwiftUI

/// v1.1 macOS Shell — NavigationSplitView：sidebar 4 项 + detail 渲染 4 个共用 Screen。
/// 设置/账号通过头像菜单弹 sheet。Composer 由 ⌘K 触发的全局 sheet。
struct MacShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppSection = .today
    @State private var showingSettings = false
    @State private var showingComposer = false
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            MacSidebar(
                selection: $selection,
                openSettings: { showingSettings = true },
                signOut: { Task { await model.logout() } }
            )
            .navigationSplitViewColumnWidth(min: 224, ideal: 248, max: 280)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 980, minHeight: 720)
        .searchable(text: $search,
                    placement: .toolbar,
                    prompt: "搜索或问 Agent")
        .onSubmit(of: .search) {
            let text = search.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            model.universalComposerViewModel.open(prefill: text)
            showingComposer = true
            search = ""
        }
        .toolbar { shellToolbar }
        .sheet(isPresented: $showingComposer) {
            ComposerSheet(isPresented: $showingComposer)
                .environmentObject(model)
                .frame(width: 620, height: 420)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(isPresented: $showingSettings)
                .environmentObject(model)
                .frame(width: 560, height: 620)
        }
        .sheet(isPresented: confirmationSheetBinding) {
            if let prompt = model.agentReview.pendingConfirmation {
                AgentConfirmationSheet(
                    prompt: prompt,
                    onConfirm: { Task { await model.confirmAgentCommand() } },
                    onCancel: { model.cancelAgentCommand() }
                )
                .environmentObject(model)
                .frame(width: 480)
            }
        }
        .background(keyboardCommands)
        .onChange(of: model.universalComposerViewModel.isOpen) { _, newValue in
            showingComposer = newValue
        }
        .onChange(of: showingComposer) { _, newValue in
            if !newValue, model.universalComposerViewModel.isOpen {
                model.universalComposerViewModel.close()
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch selection {
            case .today:    TodayScreen(jumpTo: { selection = $0 })
            case .plan:     PlanScreen()
            case .calendar: CalendarScreen()
            case .agent:    AgentScreen()
            default:        TodayScreen(jumpTo: { selection = $0 })
            }
        }
        .navigationTitle(selection.title)
    }

    @ToolbarContentBuilder
    private var shellToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.universalComposerViewModel.open()
                showingComposer = true
            } label: {
                Label("Universal Composer", systemImage: "sparkles")
            }
            .help("Universal Composer (⌘K)")
        }
    }

    // v1.2.4 P5-2 (#32): visibility-only binding (see IOSShell for rationale).
    private var confirmationSheetBinding: Binding<Bool> {
        Binding(
            get: { model.agentReview.showConfirmationSheet && model.agentReview.pendingConfirmation != nil },
            set: { newValue in
                if newValue {
                    model.openAgentConfirmationSheet()
                } else {
                    model.dismissAgentConfirmationSheet()
                }
            }
        )
    }

    @ViewBuilder
    private var keyboardCommands: some View {
        ZStack {
            Button("Universal Composer") {
                model.universalComposerViewModel.open()
                showingComposer = true
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Refresh") {
                Task { await model.refreshAll() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.isLoading)

            Button("Settings") { showingSettings = true }
                .keyboardShortcut(",", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

// MARK: - Sidebar

private struct MacSidebar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: AppSection
    let openSettings: () -> Void
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Brand
            HStack(spacing: AppTheme.Spacing.md) {
                BrandMark(size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("100J")
                        .font(.headline.weight(.semibold))
                    Text("Personal Affairs · v1.1")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.md)

            List(selection: $selection) {
                Section {
                    ForEach(AppSection.primary) { section in
                        SidebarRow(section: section, count: count(for: section), isActive: selection == section)
                            .tag(section)
                    }
                } header: {
                    Text("焦点")
                        .font(.caption2.weight(.bold))
                        .tracking(0.08)
                        .foregroundStyle(.tertiary)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            AccountFooter(
                userName: userName,
                userInitial: userInitial,
                statusState: model.syncStatus,
                openSettings: openSettings,
                signOut: signOut
            )
            .padding(AppTheme.Spacing.md)
        }
        .background(.regularMaterial)
    }

    private func count(for section: AppSection) -> Int? {
        switch section {
        case .today:
            let n = model.todayViewModel.topThree.count + model.todayViewModel.upcoming.count
            return n > 0 ? n : nil
        case .plan:
            let n = model.activePersonalTasks.count + model.activeCompanyTasks.count
            return n > 0 ? n : nil
        case .calendar:
            let n = CalendarViewState.items(on: Date(), from: model.calendarItems).count
            return n > 0 ? n : nil
        case .agent:
            return model.agentReview.pendingConfirmation == nil ? nil : 1
        default: return nil
        }
    }

    private var userName: String {
        model.currentUser?.displayName?.nilIfBlank
            ?? model.currentUser?.email?.nilIfBlank
            ?? "100J User"
    }

    private var userInitial: String {
        String(userName.prefix(1))
    }
}

private struct SidebarRow: View {
    let section: AppSection
    let count: Int?
    let isActive: Bool

    var body: some View {
        Label {
            HStack {
                Text(section.title)
                    .font(.callout.weight(isActive ? .semibold : .medium))
                Spacer(minLength: 6)
                if let count {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isActive ? AnyShapeStyle(section.accent) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .frame(minWidth: 22, minHeight: 18)
                        .background(
                            (isActive ? section.accent : Color.primary).opacity(0.10),
                            in: Capsule()
                        )
                }
            }
        } icon: {
            Image(systemName: section.systemImage)
                .symbolVariant(isActive ? .fill : .none)
                .foregroundStyle(isActive ? section.accent : .secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct AccountFooter: View {
    let userName: String
    let userInitial: String
    let statusState: AppSyncStatus
    let openSettings: () -> Void
    let signOut: () -> Void

    var body: some View {
        Menu {
            Button {
                openSettings()
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            Divider()
            Button(role: .destructive, action: signOut) {
                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                AvatarBadge(initial: userInitial)
                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    SyncStatusDot(state: statusState)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
#endif
