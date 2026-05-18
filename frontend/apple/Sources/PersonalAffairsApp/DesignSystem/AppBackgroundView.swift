import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            base
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.86)
        }
        .ignoresSafeArea()
    }

    private var base: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.15) : AppTheme.Colors.windowBackground
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.18, green: 0.20, blue: 0.24).opacity(0.88),
                Color(red: 0.12, green: 0.13, blue: 0.15),
                Color(red: 0.08, green: 0.09, blue: 0.11)
            ]
        }
        return [
            Color.white.opacity(0.45),
            AppTheme.Colors.windowBackground,
            Color(red: 0.86, green: 0.84, blue: 0.79)
        ]
    }
}
