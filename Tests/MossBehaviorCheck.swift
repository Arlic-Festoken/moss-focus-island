import Foundation

@main
struct MossBehaviorCheck {
    @MainActor
    static func main() {
        let suiteName = "MossBehaviorCheck.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let standardDefaults = UserDefaults.standard
        let v1Key = "moss.activeRun.v1"
        let v2Key = "moss.activeRun.v2"
        let savedV1 = standardDefaults.data(forKey: v1Key)
        let savedV2 = standardDefaults.data(forKey: v2Key)
        standardDefaults.removeObject(forKey: v1Key)
        standardDefaults.removeObject(forKey: v2Key)
        defer {
            if let savedV1 { standardDefaults.set(savedV1, forKey: v1Key) }
            else { standardDefaults.removeObject(forKey: v1Key) }
            if let savedV2 { standardDefaults.set(savedV2, forKey: v2Key) }
            else { standardDefaults.removeObject(forKey: v2Key) }
        }

        defaults.set(40, forKey: "focusMinutes")
        defaults.set(12, forKey: "breakMinutes")
        let taskDefaults = FocusTaskDefaults.load(from: defaults)
        precondition(taskDefaults.focusDuration == 40 * 60)
        precondition(taskDefaults.breakDuration == 12 * 60)
        precondition(taskDefaults.warmupDuration == 60)
        precondition(taskDefaults.discardThreshold == 120)
        print("configured-new-task-defaults=pass")

        let dataStore = DataStore()
        guard let task = dataStore.tasks.first else {
            fatalError("Expected a task for archive/delete checks")
        }
        let focusBefore = dataStore.totalFocus(for: task.id)

        let completed = FocusSession(
            taskID: task.id,
            taskTitle: task.title,
            projectID: task.projectID,
            projectTitle: task.category,
            category: task.category,
            plannedDuration: 1_500,
            warmupDuration: 60,
            timerActivity: .pomodoro,
            mode: .standard
        )
        dataStore.addSession(completed)
        dataStore.updateSession(id: completed.id) {
            $0.statusRaw = SessionStatus.completed.rawValue
            $0.actualFocusDuration = 900
            $0.endedAt = .now
        }

        dataStore.archiveTask(id: task.id, archived: true)
        precondition(dataStore.tasks.first(where: { $0.id == task.id })?.archived == true)
        dataStore.archiveTask(id: task.id, archived: false)
        precondition(dataStore.tasks.first(where: { $0.id == task.id })?.archived == false)

        dataStore.deleteTask(id: task.id)
        precondition(dataStore.tasks.first(where: { $0.id == task.id }) == nil)
        precondition(dataStore.sessions.contains(where: { $0.id == completed.id }))
        precondition(dataStore.totalFocus(for: task.id) == focusBefore + 900)
        print("archive-delete-history=pass")

        for id in dataStore.tasks.map(\.id) {
            dataStore.deleteTask(id: id)
        }
        precondition(dataStore.tasks.isEmpty)

        let reloaded = DataStore()
        precondition(reloaded.tasks.isEmpty, "A valid empty database must remain empty after relaunch")
        print("empty-database-remains-empty=pass")

        let lifecycleStore = reloaded
        var lifecycleTask = FocusTask(title: "Lifecycle test", category: "Tests")
        lifecycleTask.warmupDuration = 0
        lifecycleTask.discardThreshold = 0
        lifecycleTask.timerActivityRaw = TimerActivity.stopwatch.rawValue
        lifecycleStore.addTask(lifecycleTask)

        var firstSortedTask = FocusTask(title: "Sorted first", category: "Tests", sortOrder: 0)
        firstSortedTask.warmupDuration = 0
        var recentlyUsedTask = FocusTask(title: "Recently used", category: "Tests", sortOrder: 99)
        recentlyUsedTask.warmupDuration = 0
        lifecycleStore.addTask(firstSortedTask)
        lifecycleStore.addTask(recentlyUsedTask)
        let oldSession = FocusSession(
            taskID: firstSortedTask.id,
            taskTitle: firstSortedTask.title,
            projectID: firstSortedTask.projectID,
            projectTitle: firstSortedTask.category,
            category: firstSortedTask.category,
            startedAt: Date().addingTimeInterval(-3_600),
            plannedDuration: 1_500,
            warmupDuration: 0,
            timerActivity: .pomodoro,
            mode: .standard
        )
        let recentSession = FocusSession(
            taskID: recentlyUsedTask.id,
            taskTitle: recentlyUsedTask.title,
            projectID: recentlyUsedTask.projectID,
            projectTitle: recentlyUsedTask.category,
            category: recentlyUsedTask.category,
            startedAt: Date().addingTimeInterval(-60),
            plannedDuration: 1_500,
            warmupDuration: 0,
            timerActivity: .pomodoro,
            mode: .standard
        )
        let preferredStartTask = DataStore.preferredStartTask(
            from: [firstSortedTask, recentlyUsedTask],
            sessions: [oldSession, recentSession]
        )
        precondition(preferredStartTask?.id == recentlyUsedTask.id)
        print("preferred-start-task=pass")

        let archivedProject = FocusProject(title: "Archived project", symbol: "archivebox")
        lifecycleStore.addProject(archivedProject)
        let archivedChild = FocusTask(
            projectID: archivedProject.id,
            title: "Hidden child",
            category: archivedProject.title
        )
        lifecycleStore.addTask(archivedChild)
        lifecycleStore.archiveProject(id: archivedProject.id, archived: true)
        precondition(
            !lifecycleStore.startableTasks.contains(where: { $0.id == archivedChild.id }),
            "Tasks inside archived projects must not be startable"
        )
        print("archived-project-task-filter=pass")

        let appStore = AppStore()
        appStore.configure(with: lifecycleStore)
        appStore.start(task: lifecycleTask)
        appStore.pause()
        appStore.requestEnd()
        appStore.cancelReview()
        precondition(appStore.phase == .paused, "Canceling review from pause must remain paused")
        precondition(
            lifecycleStore.sessions.last?.status == .paused,
            "Canceling review from pause must keep session status paused"
        )
        appStore.resume()
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        precondition(appStore.elapsed >= 1, "Resumed timer must advance")
        appStore.requestEnd()
        appStore.finishReview(completion: .partial, blocker: .none, distraction: .none, note: "")
        print("paused-review-resume=pass")

        var pomodoroTask = lifecycleTask
        pomodoroTask.id = UUID()
        pomodoroTask.title = "Pomodoro break test"
        pomodoroTask.timerActivityRaw = TimerActivity.pomodoro.rawValue
        pomodoroTask.focusDuration = 60
        lifecycleStore.addTask(pomodoroTask)
        let pomodoroStore = AppStore()
        standardDefaults.removeObject(forKey: v2Key)
        pomodoroStore.configure(with: lifecycleStore)
        pomodoroStore.start(task: pomodoroTask)
        pomodoroStore.requestEnd()
        pomodoroStore.finishReview(completion: .partial, blocker: .none, distraction: .none, note: "")
        precondition(pomodoroStore.phase == .breakTime, "Pomodoro intervals should offer a break after review")
        pomodoroStore.skipBreak()
        print("pomodoro-partial-break=pass")

        var interruptionTask = lifecycleTask
        interruptionTask.id = UUID()
        interruptionTask.title = "Interruption persistence test"
        lifecycleStore.addTask(interruptionTask)
        let interruptionStore = AppStore()
        standardDefaults.removeObject(forKey: v2Key)
        interruptionStore.configure(with: lifecycleStore)
        interruptionStore.start(task: interruptionTask)
        interruptionStore.beginOrReturnFromInterruption()
        let interruptionCount = lifecycleStore.interruptions.count
        let restoredInterruptionStore = AppStore()
        restoredInterruptionStore.configure(with: lifecycleStore)
        restoredInterruptionStore.beginOrReturnFromInterruption()
        precondition(restoredInterruptionStore.interruptionNeedsReason)
        precondition(lifecycleStore.interruptions.count == interruptionCount)
        restoredInterruptionStore.requestEnd()
        restoredInterruptionStore.finishReview(completion: .partial, blocker: .none, distraction: .none, note: "")
        precondition(lifecycleStore.interruptions.last?.endedAt != nil)
        precondition(lifecycleStore.interruptions.last?.returnedToSameTask == false)
        print("interruption-persistence=pass")

        guard let migrationTask = lifecycleStore.tasks.first else {
            fatalError("Expected a task for migration check")
        }
        let migrationSession = FocusSession(
            taskID: migrationTask.id,
            taskTitle: migrationTask.title,
            projectID: migrationTask.projectID,
            projectTitle: migrationTask.category,
            category: migrationTask.category,
            plannedDuration: 1_500,
            warmupDuration: 0,
            timerActivity: .pomodoro,
            mode: .standard
        )
        lifecycleStore.addSession(migrationSession)
        let previousV2 = PreviousV2RunFixture(
            phase: .paused,
            sessionID: migrationSession.id,
            taskID: migrationTask.id,
            taskTitle: migrationTask.title,
            projectID: migrationTask.projectID,
            projectTitle: migrationTask.category,
            category: migrationTask.category,
            startedAt: Date().addingTimeInterval(-90),
            plannedDuration: 1_500,
            warmupDuration: 60,
            discardThreshold: 120,
            accumulatedPausedDuration: 0,
            pauseStartedAt: Date().addingTimeInterval(-5),
            mode: .standard,
            timerActivity: .pomodoro,
            focusEndedAt: nil,
            breakStartedAt: nil,
            breakDuration: 300
        )
        standardDefaults.removeObject(forKey: v1Key)
        standardDefaults.set(try! JSONEncoder().encode(previousV2), forKey: v2Key)
        let previousV2Store = AppStore()
        previousV2Store.configure(with: lifecycleStore)
        precondition(previousV2Store.phase == .paused)
        print("previous-v2-run-compatibility=pass")

        let legacyRun = LegacyRunFixture(
            phase: .paused,
            sessionID: migrationSession.id,
            taskID: migrationTask.id,
            taskTitle: migrationTask.title,
            category: migrationTask.category,
            startedAt: Date().addingTimeInterval(-120),
            plannedDuration: 1_500,
            accumulatedPausedDuration: 0,
            pauseStartedAt: Date().addingTimeInterval(-10),
            mode: .standard,
            focusEndedAt: nil,
            breakStartedAt: nil,
            breakDuration: 300
        )
        standardDefaults.removeObject(forKey: v2Key)
        standardDefaults.set(try! JSONEncoder().encode(legacyRun), forKey: v1Key)
        let migratedStore = AppStore()
        migratedStore.configure(with: lifecycleStore)
        precondition(migratedStore.phase == .paused)
        precondition(standardDefaults.data(forKey: v2Key) != nil)
        precondition(standardDefaults.data(forKey: v1Key) == nil)
        print("legacy-active-run-migration=pass")

        let exportProject = FocusProject(
            title: "Export project",
            symbol: "shippingbox.fill",
            archived: true
        )
        var exportTask = FocusTask(
            projectID: exportProject.id,
            title: "Export task",
            category: exportProject.title
        )
        exportTask.breakDuration = 20 * 60
        let exportData = try! ExportService.jsonData(
            projects: [exportProject],
            tasks: [exportTask],
            sessions: []
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try! decoder.decode(MossExport.self, from: exportData)
        precondition(payload.projects.first?.symbol == "shippingbox.fill")
        precondition(payload.projects.first?.archived == true)
        precondition(payload.tasks.first?.breakDuration == 20 * 60)
        print("json-export-roundtrip=pass")
    }
}

private struct LegacyRunFixture: Codable {
    var phase: FocusPhase
    var sessionID: UUID
    var taskID: UUID
    var taskTitle: String
    var category: String
    var startedAt: Date
    var plannedDuration: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
    var mode: FocusMode
    var focusEndedAt: Date?
    var breakStartedAt: Date?
    var breakDuration: TimeInterval
}

private struct PreviousV2RunFixture: Codable {
    var phase: FocusPhase
    var sessionID: UUID
    var taskID: UUID
    var taskTitle: String
    var projectID: UUID?
    var projectTitle: String
    var category: String
    var startedAt: Date
    var plannedDuration: TimeInterval
    var warmupDuration: TimeInterval
    var discardThreshold: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
    var mode: FocusMode
    var timerActivity: TimerActivity
    var focusEndedAt: Date?
    var breakStartedAt: Date?
    var breakDuration: TimeInterval
}
