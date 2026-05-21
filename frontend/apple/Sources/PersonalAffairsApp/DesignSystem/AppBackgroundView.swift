import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            base
            RadialGradient(
                colors: [
                    Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035),
                    .clear
                ],
                center: UnitPoint(x: 0.78, y: 0.12),
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [
                    Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.025),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 36,
                endRadius: 640
            )
            LinearGradient(
                colors: [
                    AppTheme.Colors.windowBackground.opacity(colorScheme == .dark ? 0.05 : 0.26),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var base: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.15) : AppTheme.Colors.windowBackground
    }
}
