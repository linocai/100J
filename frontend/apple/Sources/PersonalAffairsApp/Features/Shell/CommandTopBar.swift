import SwiftUI

struct CommandTopBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.workbenchLayout) private var layout
    @Binding var quickCaptureText: String
    @FocusState.Binding var isQuickCaptureFocused: Bool
    let primaryAction: PrimaryActionDescriptor
    let showsInspectorButton: Bool
    let onSubmitQuickCapture: () -> Void
    let onPrimaryAction: () -> Void
    let onToggleInspector: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            regularBar
            compactBar
        }
        .padding(.horizontal, layout.isCompact ? AppTheme.Spacing.lg : AppTheme.Spacing.xl)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.thinMaterial)
    }

    private var regularBar: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            statusBlock
                .frame(width: layout.centerWidth < 760 ? 170 : 220, alignment: .leading)

            QuickCaptureBar(text: $quickCaptureText, isFocused: $isQuickCaptureFocused, submit: onSubmitQuickCapture)
                .frame(maxWidth: 720)
                .layoutPriority(2)

            Spacer(minLength: AppTheme.Spacing.md)

            refreshButton

            if showsInspectorButton {
                inspectorButton
            }

            primaryActionButton(showTitle: layout.centerWidth >= 760)
        }
    }

    private var compactBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            QuickCaptureBar(text: $quickCaptureText, isFocused: $isQuickCaptureFocused, submit: onSubmitQuickCapture)
                .layoutPriority(2)
            refreshButton
            if showsInspectorButton {
                inspectorButton
            }
            primaryActionButton(showTitle: false)
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text((model.selectedSection ?? .today).title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("同步中")
                } else {
                    Circle()
                        .fill(AppTheme.Colors.successAccent)
                        .frame(width: 6, height: 6)
                    Text("刚刚同步")
                }
                Text("⌘R")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.Colors.surfaceTinted)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xs, style: .continuous))
            }
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .lineLimit(1)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await model.refreshAll() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .keyboardShortcut("r", modifiers: .command)
        .help("刷新数据")
    }

    private var inspectorButton: some View {
        Button(action: onToggleInspector) {
            Image(systemName: "sidebar.right")
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .help("打开上下文")
    }

    @ViewBuilder
    private func primaryActionButton(showTitle: Bool) -> some View {
        if showTitle {
            Button(action: onPrimaryAction) {
                Label(primaryAction.title, systemImage: primaryAction.systemImage)
            }
            .keyboardShortcut("n", modifiers: .command)
            .buttonStyle(.bordered)
            .help(primaryAction.title)
        } else {
            Button(action: onPrimaryAction) {
                Image(systemName: primaryAction.systemImage)
                    .frame(width: 30, height: 30)
            }
            .keyboardShortcut("n", modifiers: .command)
            .buttonStyle(.borderless)
            .help(primaryAction.title)
        }
    }
}
