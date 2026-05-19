import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isAuthenticated {
                #if os(iOS)
                IOSMainShellView()
                #else
                MacWorkbenchShellView()
                #endif
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
