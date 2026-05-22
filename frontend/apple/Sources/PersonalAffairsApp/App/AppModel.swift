import Foundation
import PersonalAffairsCore

#if canImport(Network)
import Network
#endif

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
    nonisolated static let defaultCloudBaseURL = "https://100j.linotsai.top/api/v1"

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
    @Published var pendingMutationCount = 0
    @Published var isNetworkReachable = true
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
    private let mutationQueue: MutationQueue
    private let diagnostics: DiagnosticLogger
    private var isReplayingMutations = false
    #if canImport(Network)
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "top.linotsai.app.PersonalAffairs.network")
    #endif

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
        let defaultBaseURL = Self.defaultCloudBaseURL
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
        self.mutationQueue = MutationQueue()
        self.diagnostics = .shared
        startNetworkMonitor()
        Task {
            await syncPendingMutationCount()
        }
    }

    deinit {
        #if canImport(Network)
        pathMonitor.cancel()
        #endif
    }

    var isAuthenticated: Bool {
        authMode == .localOwner || currentUser != nil
    }

    var hasDeviceSession: Bool {
        DeviceSessionStore.shared.hasActiveSession
    }

    var deviceSessionInfo: DeviceSessionInfo? {
        DeviceSessionStore.shared.info
    }

    var apiBaseURLString: String {
        api.baseURL.absoluteString
    }

    var apiServerHost: String {
        api.baseURL.host ?? apiBaseURLString
    }

    var isLocalDevelopmentConnection: Bool {
        if authMode == .localOwner { return true }
        guard let host = api.baseURL.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
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
        if !isNetworkReachable { return .offline }
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

    @discardableResult
    func prepareCloudOwnerSetup(baseURL: String = AppModel.defaultCloudBaseURL) -> Bool {
        let endpoint = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !endpoint.isEmpty, updateBaseURL(endpoint) else { return false }

        try? api.tokenStore.clear()
        DeviceSessionStore.shared.clearAll()
        updateAuthMode(.cloudJWT)
        selectedSection = .today
        return true
    }

    func bootstrapIfPossible() async {
        // v1.1.2 cloud 路径：只接受 device session；
        // 任何来自旧版本（v1.1.0 / v1.1.1）残留的纯 JWT token 一律静默清空，
        // 避免触发"云端登录已失效"红条闪一下。
        if authMode == .cloudJWT {
            guard DeviceSessionStore.shared.hasActiveSession else {
                if api.tokenStore.accessToken != nil || api.tokenStore.refreshToken != nil {
                    try? api.tokenStore.clear()
                }
                return
            }
            await silentBootstrap {
                try await self.authRepository.silentResume()
                self.currentUser = try await self.authRepository.me()
                self.spaces = try await self.spaceRepository.list()
                try await self.loadCoreData()
                await self.loadSupportData()
            }
            return
        }

        // localOwner 模式：直接拉取
        await run {
            self.currentUser = try await self.authRepository.me()
            self.spaces = try await self.spaceRepository.list()
            try await self.loadCoreData()
            await self.loadSupportData()
        }
    }

    /// 启动期专用：跟 `run` 一样的生命周期但**失败时不显示红条**，只清掉 device session。
    /// 设计意图：device session 失败 = 服务器端 revoke 或 365 天过期，让用户回 Setup 屏即可。
    private func silentBootstrap(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await operation()
        } catch APIClientError.unauthorized {
            try? api.tokenStore.clear()
            DeviceSessionStore.shared.clearAll()
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
        } catch {
            // 网络等暂时问题 — 保留 device session，下次启动再试
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
                bundleId: Bundle.main.bundleIdentifier ?? "top.linotsai.app.PersonalAffairs"
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

    func seedDemo() async -> Bool {
        var succeeded = false
        await run {
            _ = try await self.authRepository.seedDemo()
            try await self.loadAllData()
            succeeded = true
        }
        return succeeded
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
            supportErrorMessage = UserFacingMessage.translate(error)
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
            guard let space = self.personalSpace else { return }
            let request = draft.createRequest(spaceId: space.id, includesProject: false)
            do {
                _ = try await self.taskRepository.create(request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.taskCreate(request)) {
                    self.personalTasks.append(self.makeOptimisticTask(request: request))
                }
            }
        }
    }

    func createCompanyTask(_ draft: TaskDraft) async {
        await run {
            guard let space = self.companySpace else { return }
            let request = draft.createRequest(spaceId: space.id, includesProject: true)
            do {
                _ = try await self.taskRepository.create(request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.taskCreate(request)) {
                    self.companyTasks.append(self.makeOptimisticTask(request: request))
                }
            }
        }
    }

    func createProjectTask(_ draft: TaskDraft, projectId: String) async {
        await run {
            guard let space = self.companySpace else { return }
            var pinnedDraft = draft
            pinnedDraft.projectId = projectId
            let request = pinnedDraft.createRequest(spaceId: space.id, includesProject: true)
            do {
                _ = try await self.taskRepository.create(request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.taskCreate(request)) {
                    self.companyTasks.append(self.makeOptimisticTask(request: request))
                }
            }
        }
    }

    func updateTask(id: String, draft: TaskDraft, includesProject: Bool) async {
        await run {
            let request = draft.updateRequest(includesProject: includesProject)
            do {
                _ = try await self.taskRepository.update(id: id, request: request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.taskUpdate(id: id, request: request)) {
                    self.applyTaskUpdate(id: id, request: request)
                }
            }
        }
    }

    func completeTask(_ task: TaskItem) async {
        await run {
            do {
                _ = try await self.taskRepository.complete(id: task.id)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.taskStatus(id: task.id, status: .done)) {
                    self.applyTaskStatus(id: task.id, status: .done)
                }
            }
        }
    }

    func reopenTask(_ task: TaskItem) async {
        await run {
            do {
                _ = try await self.taskRepository.reopen(id: task.id)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.taskStatus(id: task.id, status: .active)) {
                    self.applyTaskStatus(id: task.id, status: .active)
                }
            }
        }
    }

    func toggleTaskDone(_ task: TaskItem) async {
        if task.status == .done {
            await reopenTask(task)
        } else {
            await completeTask(task)
        }
    }

    func archiveTask(_ task: TaskItem) async {
        await run {
            do {
                _ = try await self.taskRepository.archive(id: task.id)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(PendingMutation.taskArchive(id: task.id)) {
                    self.applyTaskStatus(id: task.id, status: .archived)
                }
            }
        }
    }

    // MARK: - Note CRUD

    func createNote(_ draft: NoteDraft) async {
        await run {
            guard let space = self.personalSpace else { return }
            let request = draft.createRequest(spaceId: space.id)
            do {
                _ = try await self.noteRepository.create(request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.noteCreate(request)) {
                    self.notes.append(self.makeOptimisticNote(request: request))
                }
            }
        }
    }

    func updateNote(id: String, draft: NoteDraft) async {
        await run {
            let request = draft.updateRequest()
            do {
                _ = try await self.noteRepository.update(id: id, request: request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.noteUpdate(id: id, request: request)) {
                    self.applyNoteUpdate(id: id, request: request)
                }
            }
        }
    }

    func archiveNote(_ note: Note) async {
        await run {
            do {
                _ = try await self.noteRepository.archive(id: note.id)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(PendingMutation.noteArchive(id: note.id)) {
                    self.applyNoteStatus(id: note.id, status: .archived)
                }
            }
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
            guard let space = self.companySpace else { return }
            let request = draft.createRequest(spaceId: space.id)
            do {
                _ = try await self.projectRepository.create(request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.projectCreate(request)) {
                    self.projects.append(self.makeOptimisticProject(request: request))
                }
            }
        }
    }

    func updateProject(id: String, draft: ProjectDraft) async {
        await run {
            let request = draft.updateRequest()
            do {
                _ = try await self.projectRepository.update(id: id, request: request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.projectUpdate(id: id, request: request)) {
                    self.applyProjectUpdate(id: id, request: request)
                }
            }
        }
    }

    func completeProject(_ project: Project) async {
        await run {
            do {
                _ = try await self.projectRepository.complete(id: project.id)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(PendingMutation.projectComplete(id: project.id)) {
                    self.applyProjectStatus(id: project.id, status: .completed)
                }
            }
        }
    }

    func archiveProject(_ project: Project) async {
        await run {
            do {
                _ = try await self.projectRepository.archive(id: project.id)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(PendingMutation.projectArchive(id: project.id)) {
                    self.applyProjectStatus(id: project.id, status: .archived)
                }
            }
        }
    }

    func loadProjectTasks(projectId: String, status: TaskStatus = .active) async -> [TaskItem] {
        let tasks = await projectsViewModel.tasks(projectId: projectId, status: status)
        if let error = projectsViewModel.lastError {
            errorMessage = UserFacingMessage.translate(error)
        }
        return tasks
    }

    // MARK: - Calendar CRUD

    func createCalendarItem(_ draft: CalendarDraftState) async {
        await run {
            let targetSpace = draft.spaceType == .personal ? self.personalSpace : self.companySpace
            guard let space = targetSpace else { return }
            let request = draft.createRequest(spaceId: space.id)
            do {
                _ = try await self.calendarRepository.create(request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.calendarCreate(request)) {
                    self.calendarItems.append(self.makeOptimisticCalendarItem(request: request))
                }
            }
        }
    }

    func updateCalendarItem(id: String, draft: CalendarDraftState) async {
        await run {
            let request = draft.updateRequest()
            do {
                _ = try await self.calendarRepository.update(id: id, request: request)
                try await self.loadAllData()
            } catch let error as APIClientError where error.isNetworkFailure {
                try await self.queueOfflineMutation(try PendingMutation.calendarUpdate(id: id, request: request)) {
                    self.applyCalendarUpdate(id: id, request: request)
                }
            }
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
            errorMessage = UserFacingMessage.translate(error)
        }
    }

    private func expireCloudSession() {
        guard authMode == .cloudJWT else {
            errorMessage = UserFacingMessage.translate(APIClientError.unauthorized)
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
        diagnostics.recordSession(event: "session_expired")
        errorMessage = "云端登录已失效，请重新登录。"
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

    private func queueOfflineMutation(_ mutation: PendingMutation, optimistic: () -> Void) async throws {
        let count = try await mutationQueue.enqueue(mutation)
        pendingMutationCount = count
        isNetworkReachable = false
        optimistic()
        refreshDerivedViewModels()
        errorMessage = "暂时离线。操作已保存，联网后会自动同步。"
    }

    private func syncPendingMutationCount() async {
        pendingMutationCount = await mutationQueue.pendingCount()
    }

    private func replayPendingMutations() async {
        guard !isReplayingMutations, isAuthenticated else { return }
        let count = await mutationQueue.pendingCount()
        pendingMutationCount = count
        guard count > 0 else { return }

        isReplayingMutations = true
        let result = await mutationQueue.replay(using: api)
        isReplayingMutations = false
        pendingMutationCount = result.remaining

        if result.succeeded > 0 {
            await refreshAll()
        }
        if result.droppedPermanent > 0 {
            supportErrorMessage = "部分离线操作未同步。请检查诊断日志后重试。"
        }
    }

    private func startNetworkMonitor() {
        #if canImport(Network)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isNetworkReachable = path.status == .satisfied
                if path.status == .satisfied {
                    await self.replayPendingMutations()
                }
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
        #endif
    }

    private func localUserId() -> String {
        currentUser?.id ?? "local-user"
    }

    private func localId() -> String {
        "local-\(UUID().uuidString)"
    }

    private func makeOptimisticTask(request: TaskCreateRequest) -> TaskItem {
        let now = Date()
        return TaskItem(
            id: localId(),
            userId: localUserId(),
            spaceId: request.spaceId,
            projectId: request.projectId,
            title: request.title,
            description: request.description,
            status: .active,
            priority: request.priority,
            dueDate: request.dueDate,
            remindAt: request.remindAt,
            estimatedMinutes: request.estimatedMinutes,
            source: "offline",
            completedAt: nil,
            archivedAt: nil,
            createdAt: now,
            updatedAt: now,
            version: 0
        )
    }

    private func applyTaskUpdate(id: String, request: TaskUpdateRequest) {
        replaceTask(id: id) { task in
            TaskItem(
                id: task.id,
                userId: task.userId,
                spaceId: task.spaceId,
                projectId: request.projectId ?? task.projectId,
                title: request.title ?? task.title,
                description: request.description ?? task.description,
                status: request.status ?? task.status,
                priority: request.priority ?? task.priority,
                dueDate: request.dueDate ?? task.dueDate,
                remindAt: request.remindAt ?? task.remindAt,
                estimatedMinutes: request.estimatedMinutes ?? task.estimatedMinutes,
                source: task.source,
                completedAt: task.completedAt,
                archivedAt: task.archivedAt,
                createdAt: task.createdAt,
                updatedAt: Date(),
                version: task.version
            )
        }
    }

    private func applyTaskStatus(id: String, status: TaskStatus) {
        let now = Date()
        replaceTask(id: id) { task in
            TaskItem(
                id: task.id,
                userId: task.userId,
                spaceId: task.spaceId,
                projectId: task.projectId,
                title: task.title,
                description: task.description,
                status: status,
                priority: task.priority,
                dueDate: task.dueDate,
                remindAt: task.remindAt,
                estimatedMinutes: task.estimatedMinutes,
                source: task.source,
                completedAt: status == .done ? now : nil,
                archivedAt: status == .archived ? now : nil,
                createdAt: task.createdAt,
                updatedAt: now,
                version: task.version
            )
        }
    }

    private func replaceTask(id: String, transform: (TaskItem) -> TaskItem) {
        if let index = personalTasks.firstIndex(where: { $0.id == id }) {
            personalTasks[index] = transform(personalTasks[index])
        }
        if let index = companyTasks.firstIndex(where: { $0.id == id }) {
            companyTasks[index] = transform(companyTasks[index])
        }
    }

    private func makeOptimisticNote(request: NoteCreateRequest) -> Note {
        let now = Date()
        return Note(
            id: localId(),
            userId: localUserId(),
            spaceId: request.spaceId,
            title: request.title,
            body: request.body,
            type: request.type,
            status: .active,
            linkedTaskId: nil,
            source: "offline",
            createdAt: now,
            updatedAt: now,
            version: 0
        )
    }

    private func applyNoteUpdate(id: String, request: NoteUpdateRequest) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[index]
        notes[index] = Note(
            id: note.id,
            userId: note.userId,
            spaceId: note.spaceId,
            title: request.title ?? note.title,
            body: request.body ?? note.body,
            type: request.type ?? note.type,
            status: request.status ?? note.status,
            linkedTaskId: note.linkedTaskId,
            source: note.source,
            createdAt: note.createdAt,
            updatedAt: Date(),
            version: note.version
        )
    }

    private func applyNoteStatus(id: String, status: NoteStatus) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[index]
        notes[index] = Note(
            id: note.id,
            userId: note.userId,
            spaceId: note.spaceId,
            title: note.title,
            body: note.body,
            type: note.type,
            status: status,
            linkedTaskId: note.linkedTaskId,
            source: note.source,
            createdAt: note.createdAt,
            updatedAt: Date(),
            version: note.version
        )
    }

    private func makeOptimisticProject(request: ProjectCreateRequest) -> Project {
        let now = Date()
        return Project(
            id: localId(),
            userId: localUserId(),
            spaceId: request.spaceId,
            name: request.name,
            description: request.description,
            status: .active,
            startDate: request.startDate,
            targetDate: request.targetDate,
            completedAt: nil,
            archivedAt: nil,
            createdAt: now,
            updatedAt: now,
            version: 0
        )
    }

    private func applyProjectUpdate(id: String, request: ProjectUpdateRequest) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let project = projects[index]
        projects[index] = Project(
            id: project.id,
            userId: project.userId,
            spaceId: project.spaceId,
            name: request.name ?? project.name,
            description: request.description ?? project.description,
            status: request.status ?? project.status,
            startDate: request.startDate ?? project.startDate,
            targetDate: request.targetDate ?? project.targetDate,
            completedAt: project.completedAt,
            archivedAt: project.archivedAt,
            createdAt: project.createdAt,
            updatedAt: Date(),
            version: project.version
        )
    }

    private func applyProjectStatus(id: String, status: ProjectStatus) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        let project = projects[index]
        let now = Date()
        projects[index] = Project(
            id: project.id,
            userId: project.userId,
            spaceId: project.spaceId,
            name: project.name,
            description: project.description,
            status: status,
            startDate: project.startDate,
            targetDate: project.targetDate,
            completedAt: status == .completed ? now : nil,
            archivedAt: status == .archived ? now : nil,
            createdAt: project.createdAt,
            updatedAt: now,
            version: project.version
        )
    }

    private func makeOptimisticCalendarItem(request: CalendarItemCreateRequest) -> CalendarItem {
        let now = Date()
        return CalendarItem(
            id: localId(),
            userId: localUserId(),
            spaceId: request.spaceId,
            projectId: request.projectId,
            relatedTaskId: request.relatedTaskId,
            title: request.title,
            description: request.description,
            type: request.type,
            allDay: request.allDay,
            startDate: request.startDate,
            endDate: request.endDate,
            startAt: request.startAt,
            endAt: request.endAt,
            timezone: request.timezone,
            recurrence: request.recurrence,
            remindAt: request.remindAt,
            source: "offline",
            createdAt: now,
            updatedAt: now,
            version: 0
        )
    }

    private func applyCalendarUpdate(id: String, request: CalendarItemUpdateRequest) {
        guard let index = calendarItems.firstIndex(where: { $0.id == id }) else { return }
        let item = calendarItems[index]
        calendarItems[index] = CalendarItem(
            id: item.id,
            userId: item.userId,
            spaceId: item.spaceId,
            projectId: request.projectId ?? item.projectId,
            relatedTaskId: request.relatedTaskId ?? item.relatedTaskId,
            title: request.title ?? item.title,
            description: request.description ?? item.description,
            type: request.type ?? item.type,
            allDay: request.allDay ?? item.allDay,
            startDate: request.startDate ?? item.startDate,
            endDate: request.endDate ?? item.endDate,
            startAt: request.startAt ?? item.startAt,
            endAt: request.endAt ?? item.endAt,
            timezone: request.timezone ?? item.timezone,
            recurrence: request.recurrence ?? item.recurrence,
            remindAt: request.remindAt ?? item.remindAt,
            source: item.source,
            createdAt: item.createdAt,
            updatedAt: Date(),
            version: item.version
        )
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
