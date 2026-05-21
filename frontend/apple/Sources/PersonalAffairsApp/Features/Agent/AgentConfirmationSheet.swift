import PersonalAffairsCore
import SwiftUI

struct AgentConfirmationSheet: View {
    let prompt: AgentConfirmationPrompt
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onExpired: () -> Void

    @State private var now = Date()
    @State private var didExpire = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("需要二次确认", systemImage: "exclamationmark.shield")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.summary)
                    .font(.headline.weight(.semibold))
                Text(prompt.reason)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !prompt.resources.isEmpty {
                WrappingHStack(spacing: 6, rowSpacing: 6) {
                    ForEach(prompt.resources, id: \.self) { resource in
                        Text(resource)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                Text("剩余 \(remainingText)")
                    .font(.callout.monospacedDigit())
                Spacer()
                Text(prompt.command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Button(role: .cancel) {
                    onCancel()
                } label: {
                    Label("取消", systemImage: "xmark")
                }

                Spacer()

                Button {
                    onConfirm()
                } label: {
                    Label("确认执行", systemImage: "checkmark.seal")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(remainingSeconds == 0)
            }
        }
        .padding(22)
        .onReceive(timer) { value in
            now = value
            if remainingSeconds == 0, !didExpire {
                didExpire = true
                onExpired()
            }
        }
    }

    private var remainingSeconds: Int {
        max(0, Int(prompt.expiresAt.timeIntervalSince(now)))
    }

    private var remainingText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
