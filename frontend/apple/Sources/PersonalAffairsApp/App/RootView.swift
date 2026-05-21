import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isAuthenticated {
                #if os(iOS)
                IOSShell()
                #else
                MacShell()
                #endif
            } else {
                LoginScreen()
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
