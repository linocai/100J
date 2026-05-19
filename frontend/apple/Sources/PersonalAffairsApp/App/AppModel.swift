import Foundation
import PersonalAffairsCore

@MainActor
final class AppModel: ObservableObject {
    @Published var authMode: AppAuthMode
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
    @Published var supportErrorMessage: String?
    @Published var selectedSection: AppSection? = .today

    let api: APIClient
    let authRepository: AuthRepository
    let spaceRepository: SpaceRepository
    let taskRepository: TaskRepository
    let projectRepository: ProjectRepository
    let calendarRepository: CalendarRepository
    let noteRepository: NoteRepository
    let agentRepository: AgentRepository

    init() {
        #if DEBUG
        let defaultBaseURL = "http://127.0.0.1:8000/api/v1"
        #else
        let defaultBaseURL = "https://100j.linotsai.top/api/v1"
        #endif
        let storedBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
        let storedAuthMode = UserDefaults.standard.string(forKey: "appAuthMode")
            .flatMap(AppAuthMode.init(rawValue:)) ?? .localOwner
        self.authMode = storedAuthMode
        let api = APIClient(
            baseURL: URL(string: storedBaseURL) ?? URL(string: "http://127.0.0.1:8000/api/v1")!,
            authMode: storedAuthMode
        )
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
        authMode == .localOwner || currentUser != nil
    }

    var personalSpace: Space? {
        spaces.first { $0.type == .personal }
    }

    var companySpace: Space? {
        spaces.first { $0.type == .company }
    }

    var activePersonalTasks: [TaskItem] {
        personalTasks.filter { $0.status == .active }
    }

    var activeCompanyTasks: [TaskItem] {
        companyTasks.filter { $0.status == .active }
    }

    var noProjectCompanyTasks: [TaskItem] {
        activeCompanyTasks.filter { $0.projectId == nil }
    }

    func projectName(for projectId: String?) -> String? {
        guard let projectId else { return nil }
        return projects.first { $0.id == projectId }?.name ?? "未知项目"
    }

    func spaceLabel(for spaceId: String) -> String {
        spaces.first { $0.id == spaceId }?.type.label ?? "未知空间"
    }

    func updateBaseURL(_ value: String) {
        guard let url = URL(string: value) else {
            errorMessage = "API Base URL 无效。"
            return
        }
        api.baseURL = url
        UserDefaults.standard.set(value, forKey: "apiBaseURL")
    }

    func updateAuthMode(_ mode: AppAuthMode) {
        authMode = mode
        api.authMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "appAuthMode")
        errorMessage = nil
        supportErrorMessage = nil

        if mode == .localOwner {
            try? api.tokenStore.clear()
            currentUser = nil
            Task { await bootstrapIfPossible() }
        } else {
            currentUser = nil
            spaces = []
            personalTasks = []
            companyTasks = []
            projects = []
            notes = []
            calendarItems = []
            agentTools = []
            agentLogs = []
            llmKey = nil
        }
    }

    func bootstrapIfPossible() async {
        if authMode == .cloudJWT, api.tokenStore.accessToken == nil { return }
        await run {
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadCoreData()
            await self.loadSupportData()
        }
    }

    func login(email: String, password: String) async {
        updateAuthMode(.cloudJWT)
        await run {
            _ = try await self.authRepository.login(email: email, password: password)
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadCoreData()
            await self.loadSupportData()
        }
    }

    func register(email: String, password: String, displayName: String?) async {
        updateAuthMode(.cloudJWT)
        await run {
            _ = try await self.authRepository.register(email: email, password: password, displayName: displayName)
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadCoreData()
            await self.loadSupportData()
        }
    }

    func logout() async {
        guard authMode == .cloudJWT else {
            await bootstrapIfPossible()
            return
        }
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
            if self.spaces.isEmpty {
                self.currentUser = try await self.authRepository.me()
                self.spaces = try await self.spaceRepository.list()
            }
            try await self.loadCoreData()
            await self.loadSupportData()
        }
    }

    func loadAllData() async throws {
        try await loadCoreData()
        await loadSupportData()
    }

    func loadCoreData() async throws {
        guard let personalSpace, let companySpace else { return }
        let window = calendarWindow()
        async let personalTasks = taskRepository.list(spaceId: personalSpace.id, status: .active)
        async let companyTasks = taskRepository.list(spaceId: companySpace.id, status: .active)
        async let projects = projectRepository.list(spaceId: companySpace.id, status: .active)
        async let notes = noteRepository.list(status: .active)
        async let calendarItems = calendarRepository.merged(
            personalSpaceId: personalSpace.id,
            companySpaceId: companySpace.id,
            fromDate: window.fromDate,
            toDate: window.toDate
        )

        self.personalTasks = try await personalTasks
        self.companyTasks = try await companyTasks
        self.projects = try await projects
        self.notes = try await notes
        self.calendarItems = try await calendarItems
    }

    func loadSupportData() async {
        supportErrorMessage = nil
        do {
            agentTools = try await agentRepository.tools()
        } catch {
            supportErrorMessage = error.localizedDescription
        }
        do {
            agentLogs = try await agentRepository.logs()
        } catch {
            supportErrorMessage = supportErrorMessage ?? error.localizedDescription
        }
        do {
            llmKey = try await agentRepository.llmKey()
        } catch {
            supportErrorMessage = supportErrorMessage ?? error.localizedDescription
        }
    }

    func reloadPersonalTasks(status: TaskStatus = .active, search: String? = nil) async {
        await run {
            guard let personalSpace = self.personalSpace else { return }
            let query = PersonalTasksViewState.query(
                personalSpaceId: personalSpace.id,
                status: status,
                search: search
            )
            self.personalTasks = try await self.taskRepository.list(query: query)
        }
    }

    func reloadCompanyTasks(status: TaskStatus = .active, projectScope: String? = nil, projectId: String? = nil, search: String? = nil) async {
        await run {
            guard let companySpace = self.companySpace else { return }
            let scope = CompanyTaskScope(pickerValue: projectScope ?? (projectId == nil ? "all" : "project"), selectedProjectId: projectId)
            let query = scope.query(
                companySpaceId: companySpace.id,
                status: status,
                search: search
            )
            self.companyTasks = try await self.taskRepository.list(query: query)
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
            let window = self.calendarWindow()
            switch filter {
            case .all:
                self.calendarItems = try await self.calendarRepository.merged(
                    personalSpaceId: personalSpace.id,
                    companySpaceId: companySpace.id,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            case .personal:
                self.calendarItems = try await self.calendarRepository.list(
                    spaceId: personalSpace.id,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            case .company:
                self.calendarItems = try await self.calendarRepository.list(
                    spaceId: companySpace.id,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            case .project(let projectId):
                self.calendarItems = try await self.calendarRepository.list(
                    spaceId: companySpace.id,
                    projectId: projectId,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            }
        }
    }

    func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func calendarWindow() -> (fromDate: String, toDate: String) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let from = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let to = calendar.date(byAdding: .day, value: 180, to: today) ?? today
        return (from.dayKey, to.dayKey)
    }
}

enum CalendarFilter: Hashable {
    case all
    case personal
    case company
    case project(String)
}
