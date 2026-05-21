import PersonalAffairsCore
import SwiftUI

#if os(macOS)
import AppKit

struct MacWorkbenchShellView: View {
    @EnvironmentObject private var model: AppModel
    @State private var inspectorSelection: InspectorSelection?
    @State private var isInspectorPresented = false
    @State private var showingSettings = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            MacSidebarView(
                selection: $model.selectedSection,
                openSettings: { showingSettings = true },
                switchAccount: switchAccount,
                openAbout: openAbout
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 280)
        } detail: {
            detailContainer
        }
        .frame(
            minWidth: AppTheme.Layout.minimumWindowWidth,
            minHeight: AppTheme.Layout.minimumWindowHeight
        )
        .toolbar { shellToolbar }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索或输入一句命令")
        .onSubmit(of: .search, submitSearch)
        .sheet(isPresented: composerPresented) {
            UniversalComposerView(vm: model.universalComposerViewModel)
                .environmentObject(model)
                .frame(width: 620, height: 380)
                .presentationBackground(.thinMaterial)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(model)
                .frame(width: 560, height: 620)
        }
        .sheet(item: confirmationPrompt) { prompt in
            AgentConfirmationSheet(
                prompt: prompt,
                onConfirm: { Task { await model.confirmAgentCommand() } },
                onCancel: { model.cancelAgentCommand() },
                onExpired: {
                    model.cancelAgentCommand()
                    model.errorMessage = "token 已过期，请重新发送指令。"
                }
            )
            .frame(width: 480)
            .presentationBackground(.regularMaterial)
        }
        .background(keyboardShortcuts)
    }

    private var detailContainer: some View {
        GeometryReader { geometry in
            let layout = WorkbenchLayoutContext(
                windowWidth: geometry.size.width,
                centerWidth: geometry.size.width,
                showsInspector: isInspectorPresented
            )
            currentWorkspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                .environment(\.workbenchLayout, layout)
        }
        .navigationTitle((model.selectedSection ?? .today).title)
        .inspector(isPresented: $isInspectorPresented) {
            ContextInspectorView(selection: inspectorSelection)
                .environmentObject(model)
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var shellToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                Image(systemName: (model.selectedSection ?? .today).systemImage)
                    .foregroundStyle(Color.indigo)
                Text((model.selectedSection ?? .today).title)
                    .font(.headline.weight(.semibold))
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.universalComposerViewModel.open()
            } label: {
                Label("Universal Composer", systemImage: "sparkles")
            }
            .help("Universal Composer (⌘K)")

            Button {
                isInspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
                    .symbolVariant(isInspectorPresented ? .fill : .none)
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
            .help("切换 Inspector (⌥⌘0)")
        }
    }

    @ViewBuilder
    private var currentWorkspace: some View {
        switch model.selectedSection ?? .today {
        case .today:
            TodayCommandView(
                selection: inspectorSelection,
                selectTask: { inspectorSelection = .task($0.id) },
                selectCalendarItem: { inspectorSelection = .calendarItem($0.id) },
                jumpToSection: jump
            )
        case .plan, .personalTasks, .personalNotes, .companyTasks, .companyProjects:
            PlanView(
                selection: inspectorSelection,
                selectTask: { inspectorSelection = .task($0.id) },
                selectProject: { inspectorSelection = .project($0.id) },
                selectNote: { inspectorSelection = .note($0.id) }
            )
        case .calendar:
            GlobalCalendarView(
                selection: inspectorSelection,
                onSelectCalendarItem: { inspectorSelection = .calendarItem($0.id) }
            )
        case .agent:
            AgentView(onSelectAgentLog: { inspectorSelection = .agentLog($0.id) })
        case .settings:
            SettingsView()
        }
    }

    private var composerPresented: Binding<Bool> {
        Binding(
            get: { model.universalComposerViewModel.isOpen },
            set: { newValue in
                if newValue {
                    model.universalComposerViewModel.open()
                } else {
                    model.universalComposerViewModel.close()
                }
            }
        )
    }

    private var confirmationPrompt: Binding<AgentConfirmationPrompt?> {
        Binding(
            get: { model.agentReview.pendingConfirmation },
            set: { newValue in
                if newValue == nil, model.agentReview.pendingConfirmation != nil {
                    model.cancelAgentCommand()
                }
            }
        )
    }

    @ViewBuilder
    private var keyboardShortcuts: some View {
        ZStack {
            Button("Universal Composer") {
                model.universalComposerViewModel.open()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Refresh") {
                Task { await model.refreshAll() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.isLoading)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func submitSearch() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.universalComposerViewModel.open(prefill: text)
        searchText = ""
    }

    private func jump(_ section: AppSection) {
        switch section {
        case .personalTasks, .personalNotes, .companyTasks, .companyProjects:
            model.selectedSection = .plan
        default:
            model.selectedSection = section
        }
    }

    private func switchAccount() {
        if model.authMode == .localOwner {
            model.updateAuthMode(.cloudJWT)
        } else {
            Task { await model.logout() }
        }
    }

    private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
#endif
