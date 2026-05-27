#if os(iOS)
import PersonalAffairsCore
import SwiftUI

/// v1.1 iOS Shell — TabView 4 项 + Liquid Glass tab bar。
///
/// v1.2.4.2 (P1-7): the right-top "⊕" Composer button, the Composer sheet
/// and the bridge to `universalComposerViewModel.isOpen` have all been
/// removed. Quick-add now happens inline at the top of each Plan tab via
/// `InlineQuickAddRow`. The Agent confirmation sheet bridge (added in
/// v1.2.4.1) is preserved verbatim — confirmation is still required when
/// the Agent surface decides a write needs human approval.
struct IOSShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppSection = .today
    @State private var showingSettings = false
    // v1.2.4.1: stable @State for the confirmation sheet, mirrored from
    // model.agentReview.showConfirmationSheet via onChange. The previous
    // computed binding caused multi-sheet modal confusion in SwiftUI.
    @State private var showingConfirmation = false

    var body: some View {
        shell
            .overlay(alignment: .bottom) {
                errorBanner
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, 92)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(isPresented: $showingSettings)
                    .environmentObject(model)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingConfirmation) {
                if let prompt = model.agentReview.pendingConfirmation {
                    AgentConfirmationSheet(
                        prompt: prompt,
                        onConfirm: { Task { await model.confirmAgentCommand() } },
                        onCancel: { model.cancelAgentCommand() }
                    )
                    .environmentObject(model)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
            // v1.2.4.1: see MacShell for rationale. .onChange(of:) does not
            // re-evaluate without a view body recompute, and v1.2.4 P6-4
            // throttle starves the body of those recomputes between actions.
            // onReceive(publisher:) subscribes through Combine directly.
            //
            // v1.2.4.2 (P1-7): the universalComposerViewModel sync was
            // removed with the Composer chain. The agentReview sync below
            // MUST stay — it is what makes the Agent confirmation sheet
            // appear when the Agent surface decides a write needs approval.
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
    private var shell: some View {
        // tabBarMinimizeBehavior 是 iOS 26 SDK 才有的符号；旧 Xcode（如 CI 的
        // macos-latest runner）的编译器找不到它，#if compiler(>=6.3) 用来在
        // 老编译器里彻底跳过这一行，避免 "no member 'tabBarMinimizeBehavior'"。
        #if compiler(>=6.3)
        if #available(iOS 26.0, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            ScreenContainer(title: "Today", showSettings: $showingSettings) {
                TodayScreen { selection = $0 }
            }
            .tag(AppSection.today)
            .tabItem { Label("Today", systemImage: "sun.max") }

            ScreenContainer(title: "Plan", showSettings: $showingSettings) {
                PlanScreen()
            }
            .tag(AppSection.plan)
            .tabItem { Label("Plan", systemImage: "rectangle.3.group") }

            ScreenContainer(title: "Calendar", showSettings: $showingSettings) {
                CalendarScreen()
            }
            .tag(AppSection.calendar)
            .tabItem { Label("Calendar", systemImage: "calendar") }

            ScreenContainer(title: "Agent", showSettings: $showingSettings) {
                AgentScreen()
            }
            .tag(AppSection.agent)
            .tabItem { Label("Agent", systemImage: "sparkles") }
        }
        .toolbarBackground(.regularMaterial, for: .tabBar)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = model.errorMessage {
            ErrorBanner(message: message) {
                Task { @MainActor in model.errorMessage = nil }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// 一个统一的 iOS NavigationStack 容器：大标题 + 头像（开设置 sheet）。
///
/// v1.2.4.2 (P1-7): the leading "⊕" Composer button was removed; quick-add
/// now happens inline on each Plan tab.
private struct ScreenContainer<Content: View>: View {
    let title: String
    @Binding var showSettings: Bool
    let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title3)
                        }
                        .accessibilityLabel("设置")
                    }
                }
        }
    }
}
#endif
