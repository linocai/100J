import SwiftUI

struct SectionHeaderView: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var systemImage: String?
    var trailing: AnyView?

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = AnyView(EmptyView())
    }

    init<Trailing: View>(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .textCase(.uppercase)
                }
                Label {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                } icon: {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(AppTheme.Colors.companyAccent)
                    }
                }
                .labelStyle(.titleAndIcon)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: AppTheme.Spacing.lg)
            trailing
        }
    }
}
