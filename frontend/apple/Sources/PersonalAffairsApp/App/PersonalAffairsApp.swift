import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 680)
                #endif
                .task {
                    await model.bootstrapIfPossible()
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("刷新") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r")
            }
        }
        #endif
    }
}
