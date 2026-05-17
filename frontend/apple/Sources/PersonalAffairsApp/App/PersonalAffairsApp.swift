import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 680)
                .task {
                    await model.bootstrapIfPossible()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r")
            }
        }
    }
}

