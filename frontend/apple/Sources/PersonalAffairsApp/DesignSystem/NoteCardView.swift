import PersonalAffairsCore
import SwiftUI

struct NoteCardView: View {
    let note: Note
    var isSelected = false
    let onSelect: () -> Void
    let onConvert: () -> Void
    let onArchive: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    Image(systemName: note.type.systemImage)
                        .font(.headline)
                        .foregroundStyle(note.type == .idea ? AppTheme.Colors.warningAccent : AppTheme.Colors.agentAccent)
                        .frame(width: 30, height: 30)
                        .background((note.type == .idea ? AppTheme.Colors.warningAccent : AppTheme.Colors.agentAccent).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: onConvert) {
                            Image(systemName: "arrow.triangle.branch")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("转为待办")
                        Button(action: onArchive) {
                            Image(systemName: "archivebox")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("归档")
                    }
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .opacity(isHovering || isSelected ? 1 : 0.58)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(note.title?.trimmedOrNil ?? "未命名")
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Text(note.body)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(4)
                }

                HStack(spacing: 6) {
                    PillView(text: note.type.label, style: note.type.pillStyle)
                    if note.linkedTaskId != nil {
                        PillView(text: "已转待办", style: .success)
                    }
                    if note.source == "agent" {
                        PillView(text: "Agent", style: .agent, systemImage: "sparkles")
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding(AppTheme.Spacing.lg)
            .background(isSelected ? AppTheme.Colors.agentAccent.opacity(0.12) : Color.white.opacity(isHovering ? 0.76 : 0.54))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.agentAccent.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.title?.trimmedOrNil ?? "未命名备忘")，\(note.type.label)")
    }
}
