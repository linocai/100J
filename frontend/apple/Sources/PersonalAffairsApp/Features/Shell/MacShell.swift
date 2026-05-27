#if os(macOS)
import PersonalAffairsCore
import SwiftUI

/// v1.1 macOS Shell — NavigationSplitView：sidebar 4 项 + detail 渲染 4 个共用 Screen。
///
/// v1.2.4.2 (P1-6): the global ⌘K Composer sheet, the toolbar sparkles
/// button, and the `searchable` → Composer prefill bridge have all been
/// removed. Quick-add now happens inline at the top of each Plan tab via
/// `InlineQuickAddRow`; the search field stays but routes Enter to the
/// existing search state without summoning any sheet.
struct MacShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppSection = .today
    @State private var showingSettings = false
    // v1.2.4.1: stable @State for the confirmation sheet so all three
    // .sheet modifiers on this view get binding identities SwiftUI can
    // compare cheaply. The previous computed binding caused mac SwiftUI
    // to enter a half-modal state that swallowed clicks elsewhere in
    // the detail pane (e.g. every button on PlanScreen).
    @State private var showingConfirmation = false
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
                    prompt: "搜索")
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(isPresented: $showingSettings)
                .environmentObject(model)
                .frame(width: 560, height: 620)
        }
        .sheet(isPresented: $showingConfirmation) {
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
        // v1.2.4.1: subscribe directly to the Combine publishers instead of
        // relying on .onChange(of:). onChange only fires when the view body
        // is re-evaluated, and v1.2.4 P6-4 (#27)'s 30 s refreshAll throttle
        // means the body stops being re-evaluated between user actions; the
        // sheet would only appear at the *next* refresh tick, ~30 s after
        // tapping a button. onReceive(publisher:) subscribes through Combine
        // and fires immediately when the @Published value flips.
        //
        // v1.2.4.2 (P1-6): the universalComposerViewModel sync was removed
        // with the Composer chain. The agentReview sync below MUST stay —
        // it is what makes the Agent confirmation sheet appear when the
        // Agent surface decides a write needs human approval.
        .onReceive(model.$agentReview) { session in
            let visible = session.showConfirmationSheet && session.pendingConfirmation != nil
            if showingConfirmation != visible { showingConfirmation = visible }
        }
        .onChange(of: showingConfirmation) { _, newValue in
            if newValue {
                model.openAgentConfirmationSheet()
            } else if model.agentReview.showConfirmationSheet {
                model.dismissAgentConfirmationSheet()
            }
        }
        .task { showingConfirmation = confirmationVisible }
    }

    private var confirmationVisible: Bool {
        model.agentReview.showConfirmationSheet && model.agentReview.pendingConfirmation != nil
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

    @ViewBuilder
    private var keyboardCommands: some View {
        ZStack {
            Button("Refresh") {
                // v1.2.4 P6-4 (#27): explicit user-driven refresh always
                // bypasses the throttle.
                Task { await model.refreshAll(force: true) }
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
