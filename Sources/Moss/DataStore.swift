import Combine
import Foundation

@MainActor
final class DataStore: ObservableObject {
    @Published private(set) var projects: [FocusProject] = []
    @Published private(set) var tasks: [FocusTask] = []
    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var interruptions: [Interruption] = []
    @Published private(set) var reflections: [Reflection] = []
    @Published private(set) var snapshots: [DailySnapshot] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let directory = applicationSupport.appendingPathComponent("Moss", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("moss-data.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
        migrateProjectsIfNeeded()
        seedIfNeeded()
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

    func archiveTask(id: UUID, archived: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].archived = archived
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
        let database = MossDatabase(
            projects: projects,
            tasks: tasks,
            sessions: sessions,
            interruptions: interruptions,
            reflections: reflections,
            snapshots: snapshots
        )
        guard let data = try? encoder.encode(database) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let database = try? decoder.decode(MossDatabase.self, from: data) else {
            return
        }
        projects = database.projects
        tasks = database.tasks
        sessions = database.sessions
        interruptions = database.interruptions
        reflections = database.reflections
        snapshots = database.snapshots
        sortProjects()
        sortTasks()
    }

    private func seedIfNeeded() {
        guard tasks.isEmpty else { return }
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
}
