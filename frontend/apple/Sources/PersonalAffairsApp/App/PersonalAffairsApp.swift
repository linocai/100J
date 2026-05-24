import PersonalAffairsCore
import SwiftUI

@main
struct PersonalAffairsApp: App {
    @StateObject private var model: AppModel

    init() {
        // iOS 仍走 App Group → widget extension 能拿到 Today snapshot。
        // macOS 在 ad-hoc 签名下访问 group container 会触发 TCC 弹窗，所以走 per-app。
        #if os(iOS)
        WidgetSnapshotStore.useAppGroup("group.top.linotsai.app.PersonalAffairs")
        #endif
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
                    // v1.2.4 P6-4 (#27): explicit user-driven refresh always
                    // bypasses the throttle.
                    Task { await model.refreshAll(force: true) }
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
