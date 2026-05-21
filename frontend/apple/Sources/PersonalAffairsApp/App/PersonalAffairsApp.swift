import PersonalAffairsCore
import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model: AppModel

    init() {
        // 让 Keychain item 以 access group 作为稳定身份键 — 与
        // PersonalAffairsApp.macOS.entitlements 的 keychain-access-groups 一致。
        KeychainAccessGroup.configure("top.linotsai.app.PersonalAffairs")
        _model = StateObject(wrappedValue: AppModel())
    }

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
