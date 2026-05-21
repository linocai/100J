import SwiftUI

struct InspectorCardView<Content: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var trailing: AnyView
    let content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = AnyView(EmptyView())
        self.content = content()
    }

    init<Trailing: View>(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = AnyView(trailing())
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(AppTheme.Colors.agentAccent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                    }
                    Spacer(minLength: AppTheme.Spacing.sm)
                    trailing
                }
                content
            }
        }
    }
}
