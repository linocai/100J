#if os(iOS)
import PersonalAffairsCore
import SwiftUI

struct IOSScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct IOSBadge: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct IOSLoadingOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct IOSUnavailableView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal)
    }
}

struct IOSErrorAlert: ViewModifier {
    @EnvironmentObject private var model: AppModel

    func body(content: Content) -> some View {
        content.alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

extension View {
    func iosErrorAlert() -> some View {
        modifier(IOSErrorAlert())
    }
}

struct IOSTaskRow: View {
    let task: TaskItem
    let projectName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(task.title)
                .font(.headline)
                .strikethrough(task.status == .done)
                .lineLimit(2)
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                IOSBadge(text: task.priority.label, color: task.priority == .urgent ? .red : .secondary)
                IOSBadge(text: task.status.label)
                if let dueDate = task.dueDate {
                    IOSBadge(text: "Due \(dueDate)", color: .orange)
                }
                if let projectName {
                    IOSBadge(text: projectName, color: .blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct IOSNoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(note.title?.trimmedOrNil ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                IOSBadge(text: note.type.label)
            }
            Text(note.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if note.linkedTaskId != nil {
                IOSBadge(text: "Linked Task", color: .green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct IOSProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(project.name)
                .font(.headline)
                .lineLimit(2)
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                IOSBadge(text: project.status.label, color: .blue)
                if let targetDate = project.targetDate {
                    IOSBadge(text: "Target \(targetDate)", color: .orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct IOSCalendarRow: View {
    let item: CalendarItem
    let space: String
    let project: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                IOSBadge(text: space, color: space == "Personal" ? .green : .blue)
            }
            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                IOSBadge(text: item.type.label)
                IOSBadge(text: item.allDay ? (item.startDate ?? "All day") : (item.startAt?.shortDateTime ?? "Timed"))
                if item.projectId != nil {
                    IOSBadge(text: project, color: .blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
