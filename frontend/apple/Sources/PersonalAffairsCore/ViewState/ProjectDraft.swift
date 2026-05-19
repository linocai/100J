import Foundation

public struct ProjectDraft {
    public var name: String
    public var description: String
    public var hasStartDate: Bool
    public var startDate: Date
    public var hasTargetDate: Bool
    public var targetDate: Date

    public init(
        name: String = "",
        description: String = "",
        startDate: String? = nil,
        targetDate: String? = nil
    ) {
        self.name = name
        self.description = description
        if let parsedStartDate = CalendarViewState.parsedDateOnly(startDate) {
            self.hasStartDate = true
            self.startDate = parsedStartDate
        } else {
            self.hasStartDate = false
            self.startDate = Date()
        }
        if let parsedTargetDate = CalendarViewState.parsedDateOnly(targetDate) {
            self.hasTargetDate = true
            self.targetDate = parsedTargetDate
        } else {
            self.hasTargetDate = false
            self.targetDate = Date()
        }
    }

    public init(_ project: Project) {
        self.init(
            name: project.name,
            description: project.description ?? "",
            startDate: project.startDate,
            targetDate: project.targetDate
        )
    }

    public var startDateString: String? {
        hasStartDate ? CalendarViewState.dayKey(startDate) : nil
    }

    public var targetDateString: String? {
        hasTargetDate ? CalendarViewState.dayKey(targetDate) : nil
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedDescription: String? {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var isValid: Bool {
        !trimmedName.isEmpty
    }

    public func createRequest(spaceId: String) -> ProjectCreateRequest {
        ProjectCreateRequest(
            spaceId: spaceId,
            name: name,
            description: trimmedDescription,
            startDate: startDateString,
            targetDate: targetDateString
        )
    }

    public func updateRequest() -> ProjectUpdateRequest {
        ProjectUpdateRequest(
            name: name,
            description: trimmedDescription,
            startDate: startDateString,
            targetDate: targetDateString
        )
    }
}
