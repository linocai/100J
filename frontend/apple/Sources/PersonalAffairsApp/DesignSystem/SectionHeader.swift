import SwiftUI

/// HTML `.page-head` 对应物：eyebrow + 大字标题 + 副标题 + 右侧 trailing 槽位。
struct SectionHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let accent: Color
    let trailing: () -> Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        accent: Color = .indigo,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(0.08)
                        .textCase(.uppercase)
                        .foregroundStyle(accent)
                }
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .tracking(-0.5)
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.bottom, AppTheme.Spacing.lg)
    }
}

/// 小型 section label，常用于 GroupBox 头部 / 内嵌段落。
struct InlineSectionLabel: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    var accent: Color = .secondary

    init(title: String, subtitle: String? = nil, systemImage: String? = nil, accent: Color = .secondary) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accent = accent
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
