import Combine
import Foundation

@MainActor
final class DataStore: ObservableObject {
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
        seedIfNeeded()
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

    func save() {
        let database = MossDatabase(
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
        tasks = database.tasks
        sessions = database.sessions
        interruptions = database.interruptions
        reflections = database.reflections
        snapshots = database.snapshots
        sortTasks()
    }

    private func seedIfNeeded() {
        guard tasks.isEmpty else { return }
        tasks = [
            FocusTask(title: "浮点数与特殊值", category: "计算机组成原理", estimatedSessions: 2, sortOrder: 0),
            FocusTask(title: "精听一段技术播客", category: "英语听力", estimatedSessions: 1, sortOrder: 1),
            FocusTask(title: "梳理下一步实现", category: "项目开发", estimatedSessions: 0, sortOrder: 2)
        ]
        save()
    }

    private func sortTasks() {
        tasks.sort {
            if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
            return $0.sortOrder < $1.sortOrder
        }
    }
}
