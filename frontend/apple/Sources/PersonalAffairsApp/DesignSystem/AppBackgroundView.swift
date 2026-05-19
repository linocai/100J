import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            base
            RadialGradient(
                colors: [
                    AppTheme.Colors.companyAccent.opacity(colorScheme == .dark ? 0.18 : 0.10),
                    .clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 560
            )
            RadialGradient(
                colors: [
                    AppTheme.Colors.agentAccent.opacity(colorScheme == .dark ? 0.16 : 0.08),
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
