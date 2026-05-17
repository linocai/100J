import Foundation
import PersonalAffairsCore

@MainActor
final class AppModel: ObservableObject {
    @Published var currentUser: User?
    @Published var spaces: [Space] = []
    @Published var personalTasks: [TaskItem] = []
    @Published var companyTasks: [TaskItem] = []
    @Published var projects: [Project] = []
    @Published var notes: [Note] = []
    @Published var calendarItems: [CalendarItem] = []
    @Published var agentTools: [AgentTool] = []
    @Published var agentLogs: [AgentActionLog] = []
    @Published var llmKey: LLMKey?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSection: AppSection? = .personalTasks

    let api: APIClient
    let authRepository: AuthRepository
    let spaceRepository: SpaceRepository
    let taskRepository: TaskRepository
    let projectRepository: ProjectRepository
    let calendarRepository: CalendarRepository
    let noteRepository: NoteRepository
    let agentRepository: AgentRepository

    init() {
        let storedBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? "http://127.0.0.1:8000/api/v1"
        let api = APIClient(baseURL: URL(string: storedBaseURL) ?? URL(string: "http://127.0.0.1:8000/api/v1")!)
        self.api = api
        self.authRepository = AuthRepository(api: api)
        self.spaceRepository = SpaceRepository(api: api)
        self.taskRepository = TaskRepository(api: api)
        self.projectRepository = ProjectRepository(api: api)
        self.calendarRepository = CalendarRepository(api: api)
        self.noteRepository = NoteRepository(api: api)
        self.agentRepository = AgentRepository(api: api)
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var personalSpace: Space? {
        spaces.first { $0.type == .personal }
    }

    var companySpace: Space? {
        spaces.first { $0.type == .company }
    }

    func updateBaseURL(_ value: String) {
        guard let url = URL(string: value) else {
            errorMessage = "Invalid API base URL."
            return
        }
        api.baseURL = url
        UserDefaults.standard.set(value, forKey: "apiBaseURL")
    }

    func bootstrapIfPossible() async {
        guard api.tokenStore.accessToken != nil else { return }
        await run {
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadAllData()
        }
    }

    func login(email: String, password: String) async {
        await run {
            _ = try await self.authRepository.login(email: email, password: password)
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadAllData()
        }
    }

    func register(email: String, password: String, displayName: String?) async {
        await run {
            _ = try await self.authRepository.register(email: email, password: password, displayName: displayName)
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadAllData()
        }
    }

    func logout() async {
        await run {
            try await self.authRepository.logout()
            self.currentUser = nil
            self.spaces = []
            self.personalTasks = []
            self.companyTasks = []
            self.projects = []
            self.notes = []
            self.calendarItems = []
            self.agentLogs = []
            self.llmKey = nil
        }
    }

    func refreshAll() async {
        await run {
            try await self.loadAllData()
        }
    }

    func loadAllData() async throws {
        guard let personalSpace, let companySpace else { return }
        async let personalTasks = taskRepository.list(spaceId: personalSpace.id, status: .active)
        async let companyTasks = taskRepository.list(spaceId: companySpace.id, status: .active)
        async let projects = projectRepository.list(spaceId: companySpace.id, status: .active)
        async let notes = noteRepository.list(status: .active)
        async let calendarItems = calendarRepository.merged(personalSpaceId: personalSpace.id, companySpaceId: companySpace.id)
        async let tools = agentRepository.tools()
        async let logs = agentRepository.logs()
        async let key = agentRepository.llmKey()

        self.personalTasks = try await personalTasks
        self.companyTasks = try await companyTasks
        self.projects = try await projects
        self.notes = try await notes
        self.calendarItems = try await calendarItems
        self.agentTools = try await tools
        self.agentLogs = try await logs
        self.llmKey = try await key
    }

    func reloadPersonalTasks(status: TaskStatus = .active, search: String? = nil) async {
        await run {
            guard let personalSpace = self.personalSpace else { return }
            self.personalTasks = try await self.taskRepository.list(spaceId: personalSpace.id, status: status, search: search)
        }
    }

    func reloadCompanyTasks(status: TaskStatus = .active, projectScope: String? = nil, projectId: String? = nil, search: String? = nil) async {
        await run {
            guard let companySpace = self.companySpace else { return }
            self.companyTasks = try await self.taskRepository.list(
                spaceId: projectId == nil ? companySpace.id : nil,
                projectId: projectId,
                projectScope: projectScope,
                status: status,
                search: search
            )
        }
    }

    func reloadNotes(status: NoteStatus = .active, type: NoteType? = nil, search: String? = nil) async {
        await run {
            self.notes = try await self.noteRepository.list(status: status, type: type, search: search)
        }
    }

    func reloadProjects(status: ProjectStatus = .active) async {
        await run {
            guard let companySpace = self.companySpace else { return }
            self.projects = try await self.projectRepository.list(spaceId: companySpace.id, status: status)
        }
    }

    func reloadCalendar(filter: CalendarFilter = .all) async {
        await run {
            guard let personalSpace = self.personalSpace, let companySpace = self.companySpace else { return }
            switch filter {
            case .all:
                self.calendarItems = try await self.calendarRepository.merged(personalSpaceId: personalSpace.id, companySpaceId: companySpace.id)
            case .personal:
                self.calendarItems = try await self.calendarRepository.list(spaceId: personalSpace.id)
            case .company:
                self.calendarItems = try await self.calendarRepository.list(spaceId: companySpace.id)
            case .project(let projectId):
                self.calendarItems = try await self.calendarRepository.list(spaceId: companySpace.id, projectId: projectId)
            }
        }
    }

    func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

enum CalendarFilter: Hashable {
    case all
    case personal
    case company
    case project(String)
}

