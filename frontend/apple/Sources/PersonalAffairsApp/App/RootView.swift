import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("onboardingCompleted.v1.1") private var onboardingCompleted = false

    var body: some View {
        Group {
            if model.isAuthenticated {
                if onboardingCompleted {
                    #if os(iOS)
                    IOSMainShellView()
                    #else
                    MacWorkbenchShellView()
                    #endif
                } else {
                    OnboardingFlowView()
                }
            } else {
                AuthView()
            }
        }
        .overlay(alignment: .bottom) {
            if let message = model.errorMessage {
                ErrorBanner(message: message) {
                    Task { @MainActor in model.errorMessage = nil }
                }
                .padding()
            }
        }
        #if os(macOS)
        .background(MacWindowChromeConfigurator())
        #endif
    }
}
