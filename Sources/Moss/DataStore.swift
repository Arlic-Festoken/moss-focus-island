import Combine
import Foundation

struct DataStoreIssue: Identifiable, Equatable {
    enum Kind: Equatable {
        case unreadable
        case saveFailed
        case recoveryFailed
        case recovered
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    let canRestoreBackup: Bool
}

@MainActor
final class DataStore: ObservableObject {
    @Published private(set) var projects: [FocusProject] = []
    @Published private(set) var tasks: [FocusTask] = []
    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var interruptions: [Interruption] = []
    @Published private(set) var reflections: [Reflection] = []
    @Published private(set) var snapshots: [DailySnapshot] = []
    @Published private(set) var storageIssue: DataStoreIssue?

    var startableTasks: [FocusTask] {
        tasks.filter {
            !$0.archived && !(project(id: $0.projectID)?.archived ?? false)
        }
    }

    var preferredStartTask: FocusTask? {
        Self.preferredStartTask(from: startableTasks, sessions: sessions)
    }

    static func preferredStartTask(from tasks: [FocusTask], sessions: [FocusSession]) -> FocusTask? {
        let sortedTasks = tasks.sorted { $0.sortOrder < $1.sortOrder }
        let recentSessions = sessions.sorted { $0.startedAt > $1.startedAt }
        return recentSessions.first.flatMap { session in
            sortedTasks.first { $0.id == session.taskID }
        } ?? sortedTasks.first
    }

    private let fileURL: URL
    private let backupURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var loadedPersistedDatabase = false
    private var storageWritesAllowed = true

    init(fileURL: URL? = nil, seedIfMissing: Bool = true) {
        let resolvedFileURL: URL
        if let fileURL {
            resolvedFileURL = fileURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.homeDirectoryForCurrentUser
            resolvedFileURL = applicationSupport
                .appendingPathComponent("Moss", isDirectory: true)
                .appendingPathComponent("moss-data.json")
        }
        self.fileURL = resolvedFileURL
        backupURL = Self.backupURL(for: resolvedFileURL)

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            try FileManager.default.createDirectory(
                at: resolvedFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            storageWritesAllowed = false
            loadedPersistedDatabase = true
            storageIssue = DataStoreIssue(
                kind: .saveFailed,
                title: "无法访问本地数据目录",
                message: error.localizedDescription,
                canRestoreBackup: false
            )
            return
        }

        load()
        if storageWritesAllowed {
            migrateProjectsIfNeeded()
        }
        if seedIfMissing {
            seedIfNeeded()
        }
    }

    func addProject(_ project: FocusProject) {
        projects.append(project)
        sortProjects()
        save()
    }

    func updateProject(_ project: FocusProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        for taskIndex in tasks.indices where tasks[taskIndex].projectID == project.id {
            tasks[taskIndex].category = project.title
        }
        sortProjects()
        save()
    }

    func archiveProject(id: UUID, archived: Bool) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].archived = archived
        save()
    }

    func addTask(_ task: FocusTask) {
        tasks.append(task)
        sortTasks()
        save()
    }

    func updateTask(_ task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        sortTasks()
        save()
    }

    @discardableResult
    func moveTask(id: UUID, toProjectID: UUID?) -> Bool {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard tasks[taskIndex].projectID != toProjectID else {
            return false
        }

        let targetProject: FocusProject?
        if let toProjectID {
            guard let project = projects.first(where: {
                $0.id == toProjectID && !$0.archived
            }) else {
                return false
            }
            targetProject = project
        } else {
            targetProject = nil
        }

        let nextSortOrder = tasks
            .filter { $0.projectID == toProjectID && $0.id != id }
            .map(\.sortOrder)
            .max()
            .map { $0 + 1 } ?? 0
        tasks[taskIndex].projectID = toProjectID
        tasks[taskIndex].category = targetProject?.title ?? "未分类"
        tasks[taskIndex].sortOrder = nextSortOrder
        sortTasks()
        save()
        return true
    }

    func archiveTask(id: UUID, archived: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].archived = archived
        save()
    }

    func restoreTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].archived = false
        if let projectID = tasks[index].projectID,
           let projectIndex = projects.firstIndex(where: { $0.id == projectID }) {
            projects[projectIndex].archived = false
        }
        save()
    }

    func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func incrementCompletedSessions(taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].completedSessions += 1
        save()
    }

    func addSession(_ session: FocusSession) {
        sessions.append(session)
        save()
    }

    func updateSession(id: UUID, mutate: (inout FocusSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        mutate(&sessions[index])
        save()
    }

    func removeSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        interruptions.removeAll { $0.sessionID == id }
        reflections.removeAll { $0.sessionID == id }
        save()
    }

    func addInterruption(_ interruption: Interruption) {
        interruptions.append(interruption)
        save()
    }

    func updateInterruption(id: UUID, mutate: (inout Interruption) -> Void) {
        guard let index = interruptions.firstIndex(where: { $0.id == id }) else { return }
        mutate(&interruptions[index])
        save()
    }

    func addReflection(_ reflection: Reflection) {
        reflections.append(reflection)
        save()
    }

    func project(id: UUID?) -> FocusProject? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func sessions(for taskID: UUID) -> [FocusSession] {
        sessions.filter { $0.taskID == taskID && $0.status == .completed }
    }

    func totalFocus(for taskID: UUID) -> TimeInterval {
        sessions(for: taskID).reduce(0) { $0 + $1.actualFocusDuration }
    }

    func totalFocus(forProjectID projectID: UUID) -> TimeInterval {
        sessions
            .filter { $0.projectID == projectID && $0.status == .completed }
            .reduce(0) { $0 + $1.actualFocusDuration }
    }

    func save() {
        guard storageWritesAllowed else {
            if storageIssue == nil {
                storageIssue = DataStoreIssue(
                    kind: .saveFailed,
                    title: "本地数据暂时只读",
                    message: "请先处理数据恢复问题，再继续记录。",
                    canRestoreBackup: validatedBackup() != nil
                )
            }
            return
        }
        let database = MossDatabase(
            projects: projects,
            tasks: tasks,
            sessions: sessions,
            interruptions: interruptions,
            reflections: reflections,
            snapshots: snapshots
        )
        do {
            let data = try encoder.encode(database)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let previous = try Data(contentsOf: fileURL)
                try previous.write(to: backupURL, options: .atomic)
            }
            try data.write(to: fileURL, options: .atomic)
        } catch {
            storageIssue = DataStoreIssue(
                kind: .saveFailed,
                title: "本地数据保存失败",
                message: error.localizedDescription,
                canRestoreBackup: validatedBackup() != nil
            )
        }
    }

    func restoreBackup() {
        guard let database = validatedBackup() else {
            storageIssue = DataStoreIssue(
                kind: .recoveryFailed,
                title: "没有可用的备份",
                message: "备份文件不存在或也无法读取，原始数据文件没有被改动。",
                canRestoreBackup: false
            )
            return
        }

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let archiveURL = fileURL
                    .deletingPathExtension()
                    .appendingPathExtension("corrupt-\(Int(Date.now.timeIntervalSince1970)).json")
                try FileManager.default.copyItem(at: fileURL, to: archiveURL)
            }
            let backupData = try Data(contentsOf: backupURL)
            try backupData.write(to: fileURL, options: .atomic)
            apply(database)
            storageWritesAllowed = true
            loadedPersistedDatabase = true
            migrateProjectsIfNeeded()
            storageIssue = DataStoreIssue(
                kind: .recovered,
                title: "已从备份恢复",
                message: "损坏的原文件已另存保留，当前数据可以继续正常保存。",
                canRestoreBackup: false
            )
        } catch {
            storageIssue = DataStoreIssue(
                kind: .recoveryFailed,
                title: "备份恢复失败",
                message: error.localizedDescription,
                canRestoreBackup: true
            )
        }
    }

    func dismissStorageIssue() {
        storageIssue = nil
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let database = try decoder.decode(MossDatabase.self, from: data)
            apply(database)
            loadedPersistedDatabase = true
        } catch {
            loadedPersistedDatabase = true
            storageWritesAllowed = false
            storageIssue = DataStoreIssue(
                kind: .unreadable,
                title: "本地数据暂时无法读取",
                message: "Moss 没有覆盖原文件。\(error.localizedDescription)",
                canRestoreBackup: validatedBackup() != nil
            )
        }
    }

    private func seedIfNeeded() {
        guard !loadedPersistedDatabase else { return }
        let study = FocusProject(title: "计算机组成原理", symbol: "cpu.fill", sortOrder: 0)
        let english = FocusProject(title: "英语听力", symbol: "text.bubble.fill", sortOrder: 1)
        let development = FocusProject(title: "项目开发", symbol: "hammer.fill", sortOrder: 2)
        projects = [study, english, development]
        tasks = [
            FocusTask(projectID: study.id, title: "浮点数与特殊值", category: study.title, estimatedSessions: 2, sortOrder: 0),
            FocusTask(projectID: english.id, title: "精听一段技术播客", category: english.title, estimatedSessions: 1, sortOrder: 1),
            FocusTask(
                projectID: development.id,
                title: "梳理下一步实现",
                category: development.title,
                estimatedSessions: 0,
                sortOrder: 2,
                timerActivity: .stopwatch,
                focusDuration: 45 * 60
            )
        ]
        save()
    }

    private func migrateProjectsIfNeeded() {
        var changed = false
        if projects.isEmpty && !tasks.isEmpty {
            let titles = Array(Set(tasks.map {
                $0.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "未分类"
                    : $0.category
            })).sorted()
            projects = titles.enumerated().map {
                FocusProject(title: $0.element, sortOrder: $0.offset)
            }
            changed = true
        }

        for index in tasks.indices where tasks[index].projectID == nil {
            let title = tasks[index].category.isEmpty ? "未分类" : tasks[index].category
            if let project = projects.first(where: { $0.title == title }) {
                tasks[index].projectID = project.id
                changed = true
            }
        }

        for index in sessions.indices where sessions[index].projectID == nil {
            if let task = tasks.first(where: { $0.id == sessions[index].taskID }) {
                sessions[index].projectID = task.projectID
                sessions[index].projectTitle = project(id: task.projectID)?.title ?? task.category
            } else {
                sessions[index].projectTitle = sessions[index].category
            }
            changed = true
        }

        sortProjects()
        sortTasks()
        if changed { save() }
    }

    private func sortProjects() {
        projects.sort {
            if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
            return $0.sortOrder < $1.sortOrder
        }
    }

    private func sortTasks() {
        tasks.sort {
            if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
            return $0.sortOrder < $1.sortOrder
        }
    }

    private func apply(_ database: MossDatabase) {
        projects = database.projects
        tasks = database.tasks
        sessions = database.sessions
        interruptions = database.interruptions
        reflections = database.reflections
        snapshots = database.snapshots
        sortProjects()
        sortTasks()
    }

    private func validatedBackup() -> MossDatabase? {
        guard let data = try? Data(contentsOf: backupURL) else { return nil }
        return try? decoder.decode(MossDatabase.self, from: data)
    }

    static func backupURL(for fileURL: URL) -> URL {
        fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                "\(fileURL.deletingPathExtension().lastPathComponent).backup.json"
            )
    }
}
