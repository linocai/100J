import PersonalAffairsCore
import SwiftUI

/// HTML `.composer` 1:1 翻译。输入框 + 4 个 Quick Action + Submit。
struct ComposerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var isPresented: Bool
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            inputRow
            Divider()
            suggestions
            Spacer(minLength: 0)
            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .onAppear { focused = true }
    }

    private var inputRow: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.purple)
            TextField("一句话新建任何东西，或直接问 Agent…",
                      text: $model.universalComposerViewModel.input,
                      axis: .vertical)
                .textFieldStyle(.plain)
                .font(.title3)
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit { submit() }
            Text("ESC")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(AppTheme.Spacing.lg)
    }

    private var suggestions: some View {
        VStack(spacing: 4) {
            ForEach(Array(model.universalComposerViewModel.suggestions.enumerated()), id: \.element.id) { idx, s in
                Button {
                    Task { await pick(s) }
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: s.systemImage)
                            .foregroundStyle(.indigo)
                            .frame(width: 22)
                        Text(s.label)
                            .font(.body)
                        Spacer(minLength: 0)
                        Text(s.hint)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        idx == 0
                            ? Color.indigo.opacity(0.10)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppTheme.Spacing.sm)
    }

    private var actions: some View {
        HStack {
            Button(role: .cancel) {
                model.universalComposerViewModel.clear()
                isPresented = false
            } label: {
                Text("取消")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Spacer()

            if let draft = model.universalComposerViewModel.pendingDraft {
                Text(draft.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                submit()
            } label: {
                Label("生成", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .keyboardShortcut(.defaultAction)
            .disabled(model.universalComposerViewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(AppTheme.Spacing.lg)
    }

    private func submit() {
        Task {
            let success = await model.submitUniversalComposer()
            if success {
                model.universalComposerViewModel.clear()
                isPresented = false
            }
        }
    }

    private func pick(_ suggestion: ComposerSuggestion) async {
        _ = await model.universalComposerViewModel.pick(suggestion)
    }
}
