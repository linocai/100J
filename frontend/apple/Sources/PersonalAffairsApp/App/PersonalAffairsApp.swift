import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                #if os(macOS)
                .frame(minWidth: 980, minHeight: 720)
                #endif
                .task {
                    await model.bootstrapIfPossible()
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Universal Composer") {
                    model.universalComposerViewModel.open()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("刷新") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r")
            }
        }
        #endif

        #if os(macOS)
        MenuBarExtra("100J", systemImage: "circle.hexagongrid.fill") {
            MenuBarPanel(model: model)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
