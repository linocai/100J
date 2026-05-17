import Foundation
import PersonalAffairsCore

extension String {
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

func projectName(_ id: String?, projects: [Project]) -> String {
    guard let id else { return "No Project" }
    return projects.first { $0.id == id }?.name ?? "Unknown Project"
}

func spaceLabel(_ id: String, spaces: [Space]) -> String {
    spaces.first { $0.id == id }?.type.label ?? "Unknown"
}

