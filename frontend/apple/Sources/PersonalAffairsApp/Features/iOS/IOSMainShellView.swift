#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSMainShellView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        shell
            .sheet(isPresented: composerPresented) {
                UniversalComposerView(vm: model.universalComposerViewModel)
                    .environmentObject(model)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
            }
    }

    @ViewBuilder
    private var shell: some View {
        #if compiler(>=6.3)
        if #available(iOS 26.0, *) {
            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView(selection: selectedTab) {
            NavigationStack {
                IOSTodayScreen()
            }
            .tag(AppSection.today)
            .tabItem { Label("Today", systemImage: "sun.max") }

            NavigationStack {
                IOSPlanScreen()
            }
            .tag(AppSection.plan)
            .tabItem { Label("Plan", systemImage: "rectangle.3.group") }

            NavigationStack {
                IOSCalendarScreen()
            }
            .tag(AppSection.calendar)
            .tabItem { Label("Calendar", systemImage: "calendar") }

            NavigationStack {
                IOSAgentScreen()
            }
            .tag(AppSection.agent)
            .tabItem { Label("Agent", systemImage: "sparkles") }
        }
        .toolbarBackground(.regularMaterial, for: .tabBar)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.55)
                .onEnded { _ in model.universalComposerViewModel.open() }
        )
    }

    private var selectedTab: Binding<AppSection> {
        Binding(
            get: {
                switch model.selectedSection ?? .today {
                case .today, .plan, .calendar, .agent:
                    return model.selectedSection ?? .today
                default:
                    return .plan
                }
            },
            set: { model.selectedSection = $0 }
        )
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
}
#endif
