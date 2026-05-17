import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                #if os(macOS)
                .frame(minWidth: 1040, minHeight: 680)
                #endif
                .task {
                    await model.bootstrapIfPossible()
                }
        }
        #if os(macOS)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r")
            }
        }
        #endif
    }
}
