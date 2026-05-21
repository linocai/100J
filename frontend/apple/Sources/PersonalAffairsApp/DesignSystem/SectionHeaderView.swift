import SwiftUI

enum SectionHeaderStyle: Equatable {
    case hero
    case page
    case panel

    var titleFont: Font {
        switch self {
        case .hero: return .title2.weight(.semibold)
        case .page: return .title2.weight(.semibold)
        case .panel: return .headline.weight(.semibold)
        }
    }

    var subtitleFont: Font {
        switch self {
        case .hero: return .callout
        case .page: return .callout
        case .panel: return .caption
        }
    }
}

struct SectionHeaderView: View {
    @Environment(\.workbenchLayout) private var layout
    let style: SectionHeaderStyle
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var systemImage: String?
    var accent: Color?
    var trailing: AnyView?

    init(
        style: SectionHeaderStyle = .page,
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        accent: Color? = nil
    ) {
        self.style = style
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accent = accent
        self.trailing = AnyView(EmptyView())
    }

    init<Trailing: View>(
        style: SectionHeaderStyle = .page,
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        accent: Color? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.style = style
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accent = accent
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalHeader
            verticalHeader
        }
    }

    private var horizontalHeader: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.lg) {
            headerContent
            Spacer(minLength: AppTheme.Spacing.lg)
            trailing
        }
    }

    private var verticalHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            headerContent
            trailing
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        if showsAccentSpine, let accent {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 3, height: style == .hero ? 44 : 36)
                headerText
            }
        } else {
            headerText
        }
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .textCase(.uppercase)
            }
            Label {
                Text(title)
                    .font(layout.isCompact && style == .hero ? .title3.weight(.semibold) : style.titleFont)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(accent ?? AppTheme.Colors.companyAccent)
                }
            }
            .labelStyle(.titleAndIcon)
            if let subtitle {
                Text(subtitle)
                    .font(style.subtitleFont)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var showsAccentSpine: Bool {
        accent != nil && style != .panel
    }
}
