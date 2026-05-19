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
    @Published var agentReview = AgentReviewSession()

    let api: APIClient
    let authRepository: AuthRepository
    let spaceRepository: SpaceRepository
    let taskRepository: TaskRepository
    let projectRepository: ProjectRepository
    let calendarRepository: CalendarRepository
    let noteRepository: NoteRepository
    let agentRepository: AgentRepository

    init() {
        let defaultBaseURL = "https://100j.linotsai.top/api/v1"
        let storedBaseURL = UserDefaults.standard.string(forKey: "apiBaseURL") ?? defaultBaseURL
        let storedAuthMode: AppAuthMode
        if UserDefaults.standard.bool(forKey: "cloudOwnerDefaultMigrated") {
            storedAuthMode = UserDefaults.standard.string(forKey: "appAuthMode")
                .flatMap(AppAuthMode.init(rawValue:)) ?? .cloudJWT
        } else {
            storedAuthMode = .cloudJWT
            UserDefaults.standard.set(true, forKey: "cloudOwnerDefaultMigrated")
            UserDefaults.standard.set(AppAuthMode.cloudJWT.rawValue, forKey: "appAuthMode")
            UserDefaults.standard.set(storedBaseURL, forKey: "apiBaseURL")
        }
        self.authMode = storedAuthMode
        let api = APIClient(
            baseURL: URL(string: storedBaseURL) ?? URL(string: defaultBaseURL)!,
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

    @discardableResult
    func updateBaseURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else {
            errorMessage = "API Base URL 无效。"
            return false
        }
        api.baseURL = url
        UserDefaults.standard.set(value, forKey: "apiBaseURL")
        return true
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

    func connectCloudOwner(accessCode: String, baseURL: String? = nil) async {
        if let baseURL, !baseURL.isEmpty, !updateBaseURL(baseURL) {
            return
        }
        updateAuthMode(.cloudJWT)
        await run {
            _ = try await self.authRepository.ownerLogin(accessCode: accessCode)
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

    func reloadCalendar(query: CalendarListQuery) async {
        await run {
            let window = self.calendarWindow()
            switch query {
            case .all(let personalSpaceId, let companySpaceId):
                self.calendarItems = try await self.calendarRepository.merged(
                    personalSpaceId: personalSpaceId,
                    companySpaceId: companySpaceId,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            case .personal(let spaceId):
                self.calendarItems = try await self.calendarRepository.list(
                    spaceId: spaceId,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            case .company(let spaceId):
                self.calendarItems = try await self.calendarRepository.list(
                    spaceId: spaceId,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            case .project(let companySpaceId, let projectId):
                self.calendarItems = try await self.calendarRepository.list(
                    spaceId: companySpaceId,
                    projectId: projectId,
                    fromDate: window.fromDate,
                    toDate: window.toDate
                )
            }
        }
    }

    // MARK: - Task CRUD

    func createPersonalTask(_ draft: TaskDraft) async {
        guard let space = personalSpace else { return }
        await run {
            _ = try await self.taskRepository.create(draft.createRequest(spaceId: space.id, includesProject: false))
            try await self.loadAllData()
        }
    }

    func createCompanyTask(_ draft: TaskDraft) async {
        guard let space = companySpace else { return }
        await run {
            _ = try await self.taskRepository.create(draft.createRequest(spaceId: space.id, includesProject: true))
            try await self.loadAllData()
        }
    }

    func createProjectTask(_ draft: TaskDraft, projectId: String) async {
        guard let space = companySpace else { return }
        var pinnedDraft = draft
        pinnedDraft.projectId = projectId
        await run {
            _ = try await self.taskRepository.create(pinnedDraft.createRequest(spaceId: space.id, includesProject: true))
            try await self.loadAllData()
        }
    }

    func updateTask(id: String, draft: TaskDraft, includesProject: Bool) async {
        await run {
            _ = try await self.taskRepository.update(id: id, request: draft.updateRequest(includesProject: includesProject))
            try await self.loadAllData()
        }
    }

    func completeTask(_ task: TaskItem) async {
        await run {
            _ = try await self.taskRepository.complete(id: task.id)
            try await self.loadAllData()
        }
    }

    func reopenTask(_ task: TaskItem) async {
        await run {
            _ = try await self.taskRepository.reopen(id: task.id)
            try await self.loadAllData()
        }
    }

    func toggleTaskDone(_ task: TaskItem) async {
        await run {
            if task.status == .done {
                _ = try await self.taskRepository.reopen(id: task.id)
            } else {
                _ = try await self.taskRepository.complete(id: task.id)
            }
            try await self.loadAllData()
        }
    }

    func archiveTask(_ task: TaskItem) async {
        await run {
            _ = try await self.taskRepository.archive(id: task.id)
            try await self.loadAllData()
        }
    }

    // MARK: - Note CRUD

    func createNote(_ draft: NoteDraft) async {
        guard let space = personalSpace else { return }
        await run {
            _ = try await self.noteRepository.create(draft.createRequest(spaceId: space.id))
            try await self.loadAllData()
        }
    }

    func updateNote(id: String, draft: NoteDraft) async {
        await run {
            _ = try await self.noteRepository.update(id: id, request: draft.updateRequest())
            try await self.loadAllData()
        }
    }

    func archiveNote(_ note: Note) async {
        await run {
            _ = try await self.noteRepository.archive(id: note.id)
            try await self.loadAllData()
        }
    }

    func convertNoteToTask(_ note: Note) async {
        await run {
            let title = note.title?.trimmedOrNil ?? String(note.body.prefix(48))
            _ = try await self.noteRepository.convertToTask(noteId: note.id, request: ConvertNoteToTaskRequest(title: title))
            try await self.loadAllData()
        }
    }

    // MARK: - Project CRUD

    func createProject(_ draft: ProjectDraft) async {
        guard let space = companySpace else { return }
        await run {
            _ = try await self.projectRepository.create(draft.createRequest(spaceId: space.id))
            try await self.loadAllData()
        }
    }

    func updateProject(id: String, draft: ProjectDraft) async {
        await run {
            _ = try await self.projectRepository.update(id: id, request: draft.updateRequest())
            try await self.loadAllData()
        }
    }

    func completeProject(_ project: Project) async {
        await run {
            _ = try await self.projectRepository.complete(id: project.id)
            try await self.loadAllData()
        }
    }

    func archiveProject(_ project: Project) async {
        await run {
            _ = try await self.projectRepository.archive(id: project.id)
            try await self.loadAllData()
        }
    }

    func loadProjectTasks(projectId: String, status: TaskStatus = .active) async -> [TaskItem] {
        do {
            return try await projectRepository.tasks(projectId: projectId, status: status)
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    // MARK: - Calendar CRUD

    func createCalendarItem(_ draft: CalendarDraftState) async {
        let targetSpace = draft.spaceType == .personal ? personalSpace : companySpace
        guard let space = targetSpace else { return }
        await run {
            _ = try await self.calendarRepository.create(draft.createRequest(spaceId: space.id))
            try await self.loadAllData()
        }
    }

    func updateCalendarItem(id: String, draft: CalendarDraftState) async {
        await run {
            _ = try await self.calendarRepository.update(id: id, request: draft.updateRequest())
            try await self.loadAllData()
        }
    }

    func deleteCalendarItem(_ item: CalendarItem) async {
        await run {
            _ = try await self.calendarRepository.delete(id: item.id)
            try await self.loadAllData()
        }
    }

    // MARK: - Agent

    func composeAgentCommand() {
        guard let text = agentReview.consumeInput() else { return }
        _ = agentReview.compose(text: text, personalSpace: personalSpace, companySpace: companySpace)
    }

    func executeAgentCommand(dryRun: Bool) async {
        guard let command = agentReview.pendingCommand else { return }
        await run {
            let response = try await self.agentRepository.execute(
                command: command.command,
                arguments: command.arguments,
                dryRun: dryRun
            )
            self.agentReview.apply(response: response, dryRun: dryRun)
            try await self.loadAllData()
        }
    }

    func confirmAgentCommand() async {
        guard let prompt = agentReview.pendingConfirmation else { return }
        await run {
            let response = try await self.agentRepository.confirm(token: prompt.token)
            self.agentReview.apply(response: response, dryRun: false)
            try await self.loadAllData()
        }
    }

    func cancelAgentCommand() {
        agentReview.cancel()
    }

    func reloadAgentSupport() async {
        await run {
            self.agentTools = try await self.agentRepository.tools()
            self.agentLogs = try await self.agentRepository.logs()
            self.llmKey = try await self.agentRepository.llmKey()
        }
    }

    func saveLLMKey(provider: String, apiKey: String) async {
        await run {
            self.llmKey = try await self.agentRepository.saveLLMKey(provider: provider, apiKey: apiKey)
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
