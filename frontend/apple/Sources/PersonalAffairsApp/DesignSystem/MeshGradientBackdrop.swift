import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// 三色径向 mesh 背景。登录页与 Onboarding 共用。
/// 浅色低对比度，仅作"非纯灰"提示，不抢前景注意力。
struct MeshGradientBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseColor
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.indigo.opacity(opacity(0.18, 0.30)), .clear],
                center: UnitPoint(x: 0.12, y: 0.10),
                startRadius: 30,
                endRadius: 460
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.mint.opacity(opacity(0.16, 0.26)), .clear],
                center: UnitPoint(x: 0.92, y: 0.12),
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.orange.opacity(opacity(0.10, 0.20)), .clear],
                center: UnitPoint(x: 0.50, y: 1.05),
                startRadius: 40,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var baseColor: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }

    private func opacity(_ light: Double, _ dark: Double) -> Double {
        colorScheme == .dark ? dark : light
    }
}
