import Combine
import Foundation

@MainActor
public final class PlanViewModel: ObservableObject {
    @Published public private(set) var personalItems: [TaskItem] = []
    @Published public private(set) var companyItems: [TaskItem] = []
    @Published public private(set) var projectItems: [Project] = []
    @Published public private(set) var noteItems: [Note] = []

    private let personalTasks: () -> [TaskItem]
    private let companyTasks: () -> [TaskItem]
    private let projects: () -> [Project]
    private let notes: () -> [Note]

    public init(
        personalTasks: @escaping () -> [TaskItem],
        companyTasks: @escaping () -> [TaskItem],
        projects: @escaping () -> [Project],
        notes: @escaping () -> [Note]
    ) {
        self.personalTasks = personalTasks
        self.companyTasks = companyTasks
        self.projects = projects
        self.notes = notes
    }

    public func refresh() {
        personalItems = personalTasks().filter { $0.status == .active }
        companyItems = companyTasks().filter { $0.status == .active }
        projectItems = CompanyWorkbenchViewState.sortedProjects(projects())
        noteItems = notes().filter { $0.status == .active }
    }
}
