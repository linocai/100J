import SwiftUI

enum AdaptivePageLayout {
    static var horizontalPadding: CGFloat {
        #if os(iOS)
        return AppTheme.Spacing.lg
        #else
        return AppTheme.Spacing.xxxl
        #endif
    }

    static var topPadding: CGFloat {
        AppTheme.Spacing.xxl
    }

    static var bottomPadding: CGFloat {
        #if os(iOS)
        return 128
        #else
        return AppTheme.Spacing.xxl
        #endif
    }

    static let maxContentWidth: CGFloat = 1200
}

struct AdaptiveHeroHeader<Actions: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let actions: Actions

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.actions = actions()
    }

    var body: some View {
        #if os(iOS)
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            textBlock
            actions
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.lg) {
            textBlock
            Spacer(minLength: 0)
            actions
        }
        #endif
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 540, alignment: .leading)
        }
        .multilineTextAlignment(.leading)
    }
}

enum AdaptiveHeroActionStyle {
    case bordered
    case prominent(Color)
}

struct AdaptiveHeroActionButton: View {
    let fullTitle: String
    let compactTitle: String
    let systemImage: String
    let style: AdaptiveHeroActionStyle
    let action: () -> Void

    var body: some View {
        switch style {
        case .bordered:
            baseButton
                .buttonStyle(.bordered)
        case .prominent(let tint):
            baseButton
                .buttonStyle(.borderedProminent)
                .tint(tint)
        }
    }

    private var baseButton: some View {
        Button(action: action) {
            adaptiveLabel
                .lineLimit(1)
                .frame(minHeight: 30)
        }
        .controlSize(.large)
        .accessibilityLabel(fullTitle)
    }

    private var adaptiveLabel: some View {
        #if os(iOS)
        ViewThatFits(in: .horizontal) {
            Label(fullTitle, systemImage: systemImage)
                .fixedSize(horizontal: true, vertical: false)
            Label(compactTitle, systemImage: systemImage)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(minWidth: 28)
        }
        #else
        Label(fullTitle, systemImage: systemImage)
        #endif
    }
}
