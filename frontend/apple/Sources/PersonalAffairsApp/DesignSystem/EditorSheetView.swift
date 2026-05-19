import SwiftUI

struct EditorSheetView<Content: View>: View {
    let title: String
    let subtitle: String?
    let cancelTitle: String
    let actionTitle: String
    let isActionDisabled: Bool
    let cancel: () -> Void
    let action: () -> Void
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        cancelTitle: String = "取消",
        actionTitle: String = "保存",
        isActionDisabled: Bool = false,
        cancel: @escaping () -> Void,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.cancelTitle = cancelTitle
        self.actionTitle = actionTitle
        self.isActionDisabled = isActionDisabled
        self.cancel = cancel
        self.action = action
        self.content = content()
    }

    var body: some View {
        SurfaceView(style: .elevated, cornerRadius: AppTheme.Radius.xl, padding: AppTheme.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                SectionHeaderView(style: .page, title: title, subtitle: subtitle)
                content
                HStack {
                    Button(cancelTitle, action: cancel)
                    Spacer()
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .disabled(isActionDisabled)
                }
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(width: 560)
    }
}
