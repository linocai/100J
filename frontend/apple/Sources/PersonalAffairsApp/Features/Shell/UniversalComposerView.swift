import PersonalAffairsCore
import SwiftUI

struct UniversalComposerView: View {
    @ObservedObject var vm: UniversalComposerViewModel
    @EnvironmentObject private var model: AppModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("一句话新建任何东西，或直接问 Agent…", text: $vm.input)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($focused)
                    .onSubmit(submit)
                Text("ESC")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(16)

            Divider()

            List(vm.suggestions) { suggestion in
                Button {
                    Task {
                        _ = await vm.pick(suggestion)
                        focused = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.systemImage)
                            .foregroundStyle(Color.indigo)
                            .frame(width: 22)
                        Text(suggestion.label)
                        Spacer()
                        Text(suggestion.hint)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .overlay(alignment: .bottomTrailing) {
            Button("提交") {
                submit()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(16)
        }
        .background {
            Button("关闭") {
                vm.close()
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .onAppear {
            focused = true
        }
    }

    private func submit() {
        Task { await model.submitUniversalComposer() }
    }
}
