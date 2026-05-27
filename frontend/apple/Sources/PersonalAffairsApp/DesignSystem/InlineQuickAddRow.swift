import SwiftUI

/// v1.2.4.2 P1-1: inline single-line quick-add row used at the top of each
/// PlanScreen tab. Replaces the deleted Composer / CaptureParser sheet flow.
///
/// Behaviour:
/// - Focus → type → Enter → `onSubmit(trimmedTitle)` runs.
/// - If `onSubmit` returns `true` the field clears and keeps focus so the
///   user can keep recording entries back-to-back.
/// - If `onSubmit` returns `false` the original text stays so the user can
///   fix it; AppModel will have already surfaced an error banner.
/// - While the async submit is in flight the TextField is disabled and a
///   small ProgressView replaces the leading icon, so a flurry of Enter
///   presses cannot fire duplicate POSTs.
struct InlineQuickAddRow: View {
    let placeholder: String
    let onSubmit: (String) async -> Bool

    @State private var text: String = ""
    @State private var submitting: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            leadingIcon
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .disabled(submitting)
                .onSubmit { Task { await handleSubmit() } }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowBackground)
        )
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if submitting {
            ProgressView()
                .controlSize(.small)
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
    }

    private var rowBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemBackground)
        #else
        return Color.primary.opacity(0.06)
        #endif
    }

    private func handleSubmit() async {
        guard let trimmed = InlineQuickAddRow.sanitize(text), !submitting else { return }
        submitting = true
        let ok = await onSubmit(trimmed)
        submitting = false
        if ok {
            text = ""
            isFocused = true
        }
    }

    /// Pure helper exposed for unit tests. Returns the trimmed candidate
    /// string when it is worth submitting, or `nil` for empty / whitespace
    /// inputs that should be ignored.
    static func sanitize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
