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

/// v1.2.4.2 P1-9: `actions` defaults to `EmptyView` so every Today / Plan /
/// Calendar caller can drop its "新建" button without changing the call
/// site. The hero title / subtitle / eyebrow visuals are unchanged.
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
        @ViewBuilder actions: () -> Actions = { EmptyView() }
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
            if Actions.self != EmptyView.self {
                actions
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        #else
        HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.lg) {
            textBlock
            if Actions.self != EmptyView.self {
                Spacer(minLength: 0)
                actions
            }
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
