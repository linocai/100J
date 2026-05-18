import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.Colors.windowBackground
            LinearGradient(
                colors: [
                    Color.white.opacity(0.45),
                    AppTheme.Colors.windowBackground,
                    Color(red: 0.86, green: 0.84, blue: 0.79)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.86)
        }
        .ignoresSafeArea()
    }
}
