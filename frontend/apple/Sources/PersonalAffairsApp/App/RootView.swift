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
            } else if model.hasDeviceSession {
                // 有 device session：要么正在 silent resume，要么即将开始
                // 永远不让 SetupScreen 闪现
                ResumingPlaceholder()
            } else {
                SetupScreen()
            }
        }
        .overlay(alignment: .bottom) {
            #if os(iOS)
            if !model.isAuthenticated {
                errorBanner
            }
            #else
            errorBanner
            #endif
        }
        #if os(macOS)
        .background(MacWindowChromeConfigurator())
        #endif
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = model.errorMessage {
            ErrorBanner(message: message) {
                Task { @MainActor in model.errorMessage = nil }
            }
            .padding()
        }
    }
}

/// 启动时正在用 device session 静默换 token 的过渡态。
/// 通常 < 1s，但即便偶尔 2s 用户也能看到「在恢复」而不是空白闪屏。
struct ResumingPlaceholder: View {
    var body: some View {
        ZStack {
            MeshGradientBackdrop()
            VStack(spacing: 16) {
                BrandMark(size: 56)
                ProgressView()
                    .controlSize(.regular)
                Text("正在恢复登录…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
