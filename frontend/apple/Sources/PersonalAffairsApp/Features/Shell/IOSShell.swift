#if os(iOS)
import PersonalAffairsCore
import SwiftUI

/// v1.1 iOS Shell — TabView 4 项 + Liquid Glass tab bar + 顶部右上角 ⊕ Composer 入口。
struct IOSShell: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: AppSection = .today
    @State private var showingComposer = false
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
            .sheet(isPresented: $showingComposer) {
                ComposerSheet(isPresented: $showingComposer)
                    .environmentObject(model)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
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
            .onReceive(model.universalComposerViewModel.$isOpen) { newValue in
                if showingComposer != newValue { showingComposer = newValue }
            }
            .onChange(of: showingComposer) { _, newValue in
                if !newValue, model.universalComposerViewModel.isOpen {
                    model.universalComposerViewModel.close()
                }
            }
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
            ScreenContainer(title: "Today", showSettings: $showingSettings, openComposer: openComposer) {
                TodayScreen { selection = $0 }
            }
            .tag(AppSection.today)
            .tabItem { Label("Today", systemImage: "sun.max") }

            ScreenContainer(title: "Plan", showSettings: $showingSettings, openComposer: openComposer) {
                PlanScreen()
            }
            .tag(AppSection.plan)
            .tabItem { Label("Plan", systemImage: "rectangle.3.group") }

            ScreenContainer(title: "Calendar", showSettings: $showingSettings, openComposer: openComposer) {
                CalendarScreen()
            }
            .tag(AppSection.calendar)
            .tabItem { Label("Calendar", systemImage: "calendar") }

            ScreenContainer(title: "Agent", showSettings: $showingSettings, openComposer: openComposer) {
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

    private func openComposer() {
        model.universalComposerViewModel.open()
        showingComposer = true
    }

}

/// 一个统一的 iOS NavigationStack 容器：大标题 + 右上角 ⊕ + 头像（开设置 sheet）。
private struct ScreenContainer<Content: View>: View {
    let title: String
    @Binding var showSettings: Bool
    let openComposer: () -> Void
    let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            openComposer()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .accessibilityLabel("Universal Composer")

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
