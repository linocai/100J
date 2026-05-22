import PersonalAffairsCore
import SwiftUI

/// Agent 二次确认 sheet。倒计时显示剩余时间。
struct AgentConfirmationSheet: View {
    let prompt: AgentConfirmationPrompt
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var now = Date()
    @Environment(\.dismiss) private var dismiss
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.orange, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("需要二次确认")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(remaining)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            Text(prompt.summary)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !prompt.reason.isEmpty {
                Text(prompt.reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !prompt.resources.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(prompt.resources, id: \.self) { resource in
                            StatusPill(text: resource, color: .indigo, size: .regular)
                        }
                    }
                }
            }

            HStack(spacing: AppTheme.Spacing.md) {
                Button(role: .cancel) {
                    onCancel()
                    dismiss()
                } label: {
                    Text("取消")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Label("确认执行", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
            }
        }
        .padding(AppTheme.Spacing.xxl)
        .onReceive(timer) { now = $0 }
    }

    private var remaining: String {
        let remaining = max(0, Int(prompt.expiresAt.timeIntervalSince(now)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return "在 \(minutes):\(String(format: "%02d", seconds)) 内确认"
    }
}
