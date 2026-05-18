import PersonalAffairsCore
import SwiftUI

struct ProjectCardView: View {
    let project: Project
    let activeTaskCount: Int
    let completedTaskCount: Int
    var isSelected = false
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.callout.weight(.semibold))
                            .lineLimit(2)
                        if let description = project.description?.trimmedOrNil {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    PillView(text: project.status.label, style: project.status.pillStyle)
                }

                HStack(spacing: 6) {
                    PillView(text: "\(activeTaskCount) active", style: .company)
                    if completedTaskCount > 0 {
                        PillView(text: "\(completedTaskCount) done", style: .success)
                    }
                    if let targetDate = project.targetDate {
                        PillView(text: "Target \(targetDate)", style: .warningSubtle)
                    }
                }

                ProgressView(value: progress)
                    .tint(AppTheme.Colors.companyAccent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(AppTheme.Spacing.lg)
            .background(isSelected ? AppTheme.Colors.companyAccent.opacity(0.12) : Color.white.opacity(isHovering ? 0.76 : 0.54))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(isSelected ? AppTheme.Colors.companyAccent.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(activeTaskCount) active tasks")
    }

    private var progress: Double {
        let total = activeTaskCount + completedTaskCount
        guard total > 0 else { return 0.08 }
        return Double(completedTaskCount) / Double(total)
    }
}
