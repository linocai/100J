import Foundation
import PersonalAffairsCore

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

enum AppSyncStatus: Equatable {
    case offline
    case syncing
    case synced
    case error
}

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
    @Published var menuBarCaptureText = ""
    @Published var search = ""

    private let api: APIClient
    private let authRepository: AuthRepository
    private let spaceRepository: SpaceRepository
    private let taskRepository: TaskRepository
    private let projectRepository: ProjectRepository
    private let calendarRepository: CalendarRepository
    private let noteRepository: NoteRepository
    private let agentRepository: AgentRepository

    lazy var personalTasksViewModel = PersonalTasksViewModel(repo: taskRepository) { [weak self] in
        self?.personalSpace
    }
    lazy var companyTasksViewModel = CompanyTasksViewModel(repo: taskRepository) { [weak self] in
        self?.companySpace
    }
    lazy var projectsViewModel = ProjectsViewModel(repo: projectRepository) { [weak self] in
        self?.companySpace
    }
    lazy var notesViewModel = NotesViewModel(repo: noteRepository) { [weak self] in
        self?.personalSpace
    }
    lazy var calendarViewModel = CalendarViewModel(
        repo: calendarRepository,
        personalSpace: { [weak self] in self?.personalSpace },
        companySpace: { [weak self] in self?.companySpace },
        window: { [weak self] in self?.calendarWindow() ?? defaultCalendarWindow() }
    )
    lazy var agentViewModel = AgentViewModel(
        repo: agentRepository,
        personalSpace: { [weak self] in self?.personalSpace },
        companySpace: { [weak self] in self?.companySpace }
    )
    lazy var todayViewModel = TodayViewModel(
        personalTasks: { [weak self] in self?.personalTasks ?? [] },
        companyTasks: { [weak self] in self?.companyTasks ?? [] },
        calendarItems: { [weak self] in self?.calendarItems ?? [] },
        notes: { [weak self] in self?.notes ?? [] }
    )
    lazy var planViewModel = PlanViewModel(
        personalTasks: { [weak self] in self?.personalTasks ?? [] },
        companyTasks: { [weak self] in self?.companyTasks ?? [] },
        projects: { [weak self] in self?.projects ?? [] },
        notes: { [weak self] in self?.notes ?? [] }
    )
    lazy var universalComposerViewModel = UniversalComposerViewModel(
        personalSpace: { [weak self] in self?.personalSpace },
        companySpace: { [weak self] in self?.companySpace }
    )

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

    var syncStatus: AppSyncStatus {
        if isLoading { return .syncing }
        if errorMessage != nil || supportErrorMessage != nil { return .error }
        return isAuthenticated ? .synced : .offline
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
            refreshDerivedViewModels()
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

    #if canImport(AuthenticationServices)
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard case .success(let authorization) = result else {
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "无法完成 Apple 登录。"
            }
            return
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            errorMessage = "无法获取 Apple 身份令牌。"
            return
        }
        updateAuthMode(.cloudJWT)
        await run {
            _ = try await self.authRepository.signInWithApple(
                idToken: idToken,
                email: credential.email,
                fullName: credential.fullName?.formatted(),
                bundleId: Bundle.main.bundleIdentifier ?? "top.linotsai.100j"
            )
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadCoreData()
            await self.loadSupportData()
        }
    }
    #endif

    func requestEmailOTP(email: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@") else {
            errorMessage = "请输入有效邮箱。"
            return
        }
        updateAuthMode(.cloudJWT)
        await run {
            try await self.authRepository.requestEmailOTP(email: cleanEmail)
        }
    }

    func verifyEmailOTP(email: String, code: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@"), cleanCode.count == 6 else {
            errorMessage = "请输入邮箱和 6 位验证码。"
            return
        }
        updateAuthMode(.cloudJWT)
        await run {
            _ = try await self.authRepository.verifyEmailOTP(email: cleanEmail, code: cleanCode)
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
            self.refreshDerivedViewModels()
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
        personalTasksViewModel.filter = .active
        personalTasksViewModel.search = ""
        companyTasksViewModel.filter = .active
        companyTasksViewModel.search = ""
        companyTasksViewModel.scope = .all
        projectsViewModel.filter = .active
        projectsViewModel.search = ""
        notesViewModel.status = .active
        notesViewModel.type = nil
        notesViewModel.search = ""
        calendarViewModel.filter = .all
        calendarViewModel.selectedProjectId = nil

        await personalTasksViewModel.reload()
        try throwIfViewModelError(personalTasksViewModel.lastError)
        await companyTasksViewModel.reload()
        try throwIfViewModelError(companyTasksViewModel.lastError)
        await projectsViewModel.reload()
        try throwIfViewModelError(projectsViewModel.lastError)
        await notesViewModel.reload()
        try throwIfViewModelError(notesViewModel.lastError)
        await calendarViewModel.reload(
            query: .all(personalSpaceId: personalSpace.id, companySpaceId: companySpace.id)
        )
        try throwIfViewModelError(calendarViewModel.lastError)

        syncCoreDataFromViewModels()
    }

    func loadSupportData() async {
        supportErrorMessage = nil
        await agentViewModel.reloadSupport()
        if let error = agentViewModel.lastError {
            supportErrorMessage = error.localizedDescription
        }
        syncAgentSupportFromViewModel()
    }

    func reloadPersonalTasks(status: TaskStatus = .active, search: String? = nil) async {
        await run {
            guard self.personalSpace != nil else { return }
            self.personalTasksViewModel.filter = status
            self.personalTasksViewModel.search = search ?? ""
            await self.personalTasksViewModel.reload()
            try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
            self.personalTasks = self.personalTasksViewModel.items
            self.refreshDerivedViewModels()
        }
    }

    func reloadCompanyTasks(status: TaskStatus = .active, projectScope: String? = nil, projectId: String? = nil, search: String? = nil) async {
        await run {
            guard self.companySpace != nil else { return }
            self.companyTasksViewModel.filter = status
            self.companyTasksViewModel.search = search ?? ""
            self.companyTasksViewModel.scope = CompanyTaskScope(
                pickerValue: projectScope ?? (projectId == nil ? "all" : "project"),
                selectedProjectId: projectId
            )
            await self.companyTasksViewModel.reload()
            try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            self.companyTasks = self.companyTasksViewModel.items
            self.refreshDerivedViewModels()
        }
    }

    func reloadNotes(status: NoteStatus = .active, type: NoteType? = nil, search: String? = nil) async {
        await run {
            self.notesViewModel.status = status
            self.notesViewModel.type = type
            self.notesViewModel.search = search ?? ""
            await self.notesViewModel.reload()
            try self.throwIfViewModelError(self.notesViewModel.lastError)
            self.notes = self.notesViewModel.items
            self.refreshDerivedViewModels()
        }
    }

    func reloadProjects(status: ProjectStatus = .active) async {
        await run {
            guard self.companySpace != nil else { return }
            self.projectsViewModel.filter = status
            await self.projectsViewModel.reload()
            try self.throwIfViewModelError(self.projectsViewModel.lastError)
            self.projects = self.projectsViewModel.items
            self.refreshDerivedViewModels()
        }
    }

    func reloadCalendar(query: CalendarListQuery) async {
        await run {
            await self.calendarViewModel.reload(query: query)
            try self.throwIfViewModelError(self.calendarViewModel.lastError)
            self.calendarItems = self.calendarViewModel.items
            self.refreshDerivedViewModels()
        }
    }

    // MARK: - Task CRUD

    func createPersonalTask(_ draft: TaskDraft) async {
        await run {
            await self.personalTasksViewModel.create(draft)
            try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func createCompanyTask(_ draft: TaskDraft) async {
        await run {
            await self.companyTasksViewModel.create(draft)
            try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func createProjectTask(_ draft: TaskDraft, projectId: String) async {
        await run {
            await self.companyTasksViewModel.createProjectTask(draft, projectId: projectId)
            try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func updateTask(id: String, draft: TaskDraft, includesProject: Bool) async {
        await run {
            if includesProject {
                await self.companyTasksViewModel.update(id: id, draft: draft)
                try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            } else {
                await self.personalTasksViewModel.update(id: id, draft: draft)
                try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
            }
            try await self.loadAllData()
        }
    }

    func completeTask(_ task: TaskItem) async {
        await run {
            if task.spaceId == self.personalSpace?.id {
                await self.personalTasksViewModel.complete(task)
                try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
            } else {
                await self.companyTasksViewModel.complete(task)
                try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            }
            try await self.loadAllData()
        }
    }

    func reopenTask(_ task: TaskItem) async {
        await run {
            if task.spaceId == self.personalSpace?.id {
                await self.personalTasksViewModel.reopen(task)
                try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
            } else {
                await self.companyTasksViewModel.reopen(task)
                try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            }
            try await self.loadAllData()
        }
    }

    func toggleTaskDone(_ task: TaskItem) async {
        await run {
            if task.status == .done {
                if task.spaceId == self.personalSpace?.id {
                    await self.personalTasksViewModel.reopen(task)
                    try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
                } else {
                    await self.companyTasksViewModel.reopen(task)
                    try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
                }
            } else {
                if task.spaceId == self.personalSpace?.id {
                    await self.personalTasksViewModel.complete(task)
                    try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
                } else {
                    await self.companyTasksViewModel.complete(task)
                    try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
                }
            }
            try await self.loadAllData()
        }
    }

    func archiveTask(_ task: TaskItem) async {
        await run {
            if task.spaceId == self.personalSpace?.id {
                await self.personalTasksViewModel.archive(task)
                try self.throwIfViewModelError(self.personalTasksViewModel.lastError)
            } else {
                await self.companyTasksViewModel.archive(task)
                try self.throwIfViewModelError(self.companyTasksViewModel.lastError)
            }
            try await self.loadAllData()
        }
    }

    // MARK: - Note CRUD

    func createNote(_ draft: NoteDraft) async {
        await run {
            await self.notesViewModel.create(draft)
            try self.throwIfViewModelError(self.notesViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func updateNote(id: String, draft: NoteDraft) async {
        await run {
            await self.notesViewModel.update(id: id, draft: draft)
            try self.throwIfViewModelError(self.notesViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func archiveNote(_ note: Note) async {
        await run {
            await self.notesViewModel.archive(note)
            try self.throwIfViewModelError(self.notesViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func convertNoteToTask(_ note: Note) async {
        await run {
            await self.notesViewModel.convertToTask(note)
            try self.throwIfViewModelError(self.notesViewModel.lastError)
            try await self.loadAllData()
        }
    }

    // MARK: - Project CRUD

    func createProject(_ draft: ProjectDraft) async {
        await run {
            await self.projectsViewModel.create(draft)
            try self.throwIfViewModelError(self.projectsViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func updateProject(id: String, draft: ProjectDraft) async {
        await run {
            await self.projectsViewModel.update(id: id, draft: draft)
            try self.throwIfViewModelError(self.projectsViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func completeProject(_ project: Project) async {
        await run {
            await self.projectsViewModel.complete(project)
            try self.throwIfViewModelError(self.projectsViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func archiveProject(_ project: Project) async {
        await run {
            await self.projectsViewModel.archive(project)
            try self.throwIfViewModelError(self.projectsViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func loadProjectTasks(projectId: String, status: TaskStatus = .active) async -> [TaskItem] {
        let tasks = await projectsViewModel.tasks(projectId: projectId, status: status)
        errorMessage = projectsViewModel.lastError?.localizedDescription
        return tasks
    }

    // MARK: - Calendar CRUD

    func createCalendarItem(_ draft: CalendarDraftState) async {
        await run {
            await self.calendarViewModel.create(draft)
            try self.throwIfViewModelError(self.calendarViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func updateCalendarItem(id: String, draft: CalendarDraftState) async {
        await run {
            await self.calendarViewModel.update(id: id, draft: draft)
            try self.throwIfViewModelError(self.calendarViewModel.lastError)
            try await self.loadAllData()
        }
    }

    func deleteCalendarItem(_ item: CalendarItem) async {
        await run {
            await self.calendarViewModel.delete(item)
            try self.throwIfViewModelError(self.calendarViewModel.lastError)
            try await self.loadAllData()
        }
    }

    // MARK: - Agent

    func composeAgentCommand() {
        agentViewModel.review = agentReview
        agentViewModel.composePendingInput()
        agentReview = agentViewModel.review
    }

    func executeAgentCommand(dryRun: Bool) async {
        await run {
            self.agentViewModel.review = self.agentReview
            await self.agentViewModel.execute(dryRun: dryRun)
            try self.throwIfViewModelError(self.agentViewModel.lastError)
            self.agentReview = self.agentViewModel.review
            try await self.loadAllData()
        }
    }

    func confirmAgentCommand() async {
        await run {
            self.agentViewModel.review = self.agentReview
            await self.agentViewModel.confirm()
            try self.throwIfViewModelError(self.agentViewModel.lastError)
            self.agentReview = self.agentViewModel.review
            try await self.loadAllData()
        }
    }

    func cancelAgentCommand() {
        agentViewModel.review = agentReview
        agentViewModel.cancel()
        agentReview = agentViewModel.review
    }

    func reloadAgentSupport() async {
        await run {
            await self.agentViewModel.reloadSupport()
            try self.throwIfViewModelError(self.agentViewModel.lastError)
            self.syncAgentSupportFromViewModel()
        }
    }

    func saveLLMKey(provider: String, apiKey: String) async {
        await run {
            await self.agentViewModel.saveLLMKey(provider: provider, apiKey: apiKey)
            try self.throwIfViewModelError(self.agentViewModel.lastError)
            self.syncAgentSupportFromViewModel()
        }
    }

    @discardableResult
    func submitUniversalComposer() async -> Bool {
        guard let draft = await universalComposerViewModel.submit() else {
            errorMessage = "还没能解析这句输入。可以试试“个人待办 买牛奶”或“明天下午3点公司会议”。"
            return false
        }
        agentReview.pendingCommand = draft
        agentReview.pendingConfirmation = nil
        agentReview.responseText = "已生成可审核操作。"
        selectedSection = .agent
        universalComposerViewModel.close()
        return true
    }

    func submitMenuBarCapture() async {
        let text = menuBarCaptureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        universalComposerViewModel.input = text
        if await submitUniversalComposer() {
            menuBarCaptureText = ""
        }
    }

    func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
        } catch APIClientError.unauthorized {
            expireCloudSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func expireCloudSession() {
        guard authMode == .cloudJWT else {
            errorMessage = APIClientError.unauthorized.localizedDescription
            return
        }
        try? api.tokenStore.clear()
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
        agentViewModel.cancel()
        agentReview = agentViewModel.review
        refreshDerivedViewModels()
        errorMessage = "云端登录已失效，请重新输入访问码。"
    }

    private func syncCoreDataFromViewModels() {
        personalTasks = personalTasksViewModel.items
        companyTasks = companyTasksViewModel.items
        projects = projectsViewModel.items
        notes = notesViewModel.items
        calendarItems = calendarViewModel.items
        refreshDerivedViewModels()
    }

    private func syncAgentSupportFromViewModel() {
        agentTools = agentViewModel.tools
        agentLogs = agentViewModel.logs
        llmKey = agentViewModel.llmKey
    }

    private func refreshDerivedViewModels() {
        todayViewModel.refresh()
        planViewModel.refresh()
        refreshWidgetSnapshot()

        #if os(iOS)
        let calendarItems = calendarItems
        Task {
            await LocalNotificationCenter.shared.sync(items: calendarItems)
        }
        #endif
    }

    private func refreshWidgetSnapshot() {
        let snapshot = WidgetSnapshot(
            topThree: todayViewModel.topThree.map { task in
                WidgetTaskSnapshot(
                    id: task.id,
                    title: task.title,
                    subtitle: projectName(for: task.projectId) ?? task.priority.label,
                    priority: task.priority.label
                )
            },
            upcoming: todayViewModel.upcoming.map { schedule in
                WidgetCalendarSnapshot(
                    id: schedule.id,
                    title: schedule.item.title,
                    subtitle: projectName(for: schedule.item.projectId) ?? spaceLabel(for: schedule.item.spaceId),
                    timeLabel: schedule.timeLabel
                )
            }
        )
        WidgetSnapshotStore.save(snapshot)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func throwIfViewModelError(_ error: APIClientError?) throws {
        if let error {
            throw error
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
