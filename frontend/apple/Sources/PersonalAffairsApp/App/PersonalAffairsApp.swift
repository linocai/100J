import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model = AppModel()
    // 注：v1.1.3 曾尝试通过 keychain-access-groups 让 Keychain 用 access group 作为
    // 稳定身份键，但 ad-hoc 签名无 provisioning profile，taskgated 直接拒绝启动。
    // 现在退一步只靠稳定的 designated requirement（codesign --identifier + -r）。

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
