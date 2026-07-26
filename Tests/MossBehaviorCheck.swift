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
        let savedLaunchSilently = standardDefaults.object(forKey: "launchSilently")
        let savedSubtleSound = standardDefaults.object(forKey: "subtleSound")
        standardDefaults.removeObject(forKey: v1Key)
        standardDefaults.removeObject(forKey: v2Key)
        standardDefaults.set(true, forKey: "launchSilently")
        standardDefaults.set(false, forKey: "subtleSound")
        defer {
            if let savedV1 { standardDefaults.set(savedV1, forKey: v1Key) }
            else { standardDefaults.removeObject(forKey: v1Key) }
            if let savedV2 { standardDefaults.set(savedV2, forKey: v2Key) }
            else { standardDefaults.removeObject(forKey: v2Key) }
            if let savedLaunchSilently {
                standardDefaults.set(savedLaunchSilently, forKey: "launchSilently")
            } else {
                standardDefaults.removeObject(forKey: "launchSilently")
            }
            if let savedSubtleSound {
                standardDefaults.set(savedSubtleSound, forKey: "subtleSound")
            } else {
                standardDefaults.removeObject(forKey: "subtleSound")
            }
        }

        defaults.set(40, forKey: "focusMinutes")
        defaults.set(12, forKey: "breakMinutes")
        let taskDefaults = FocusTaskDefaults.load(from: defaults)
        precondition(taskDefaults.focusDuration == 40 * 60)
        precondition(taskDefaults.breakDuration == 12 * 60)
        precondition(taskDefaults.warmupDuration == 60)
        precondition(taskDefaults.discardThreshold == 120)
        print("configured-new-task-defaults=pass")

        let calendar = utcCalendar
        let streakSessions = (1...7).map { day in
            fixtureSession(
                title: day == 1 ? "漫游" : "计组",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: 10))!,
                duration: 1_500,
                status: .completed
            )
        }
        let abandonedFixture = fixtureSession(
            title: "漫游",
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 4, hour: 14))!,
            duration: 900,
            status: .abandoned
        )
        let analyticsFixture = FocusAnalyticsSnapshot(
            sessions: streakSessions + [abandonedFixture],
            now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 8, hour: 8))!,
            calendar: calendar
        )
        precondition(analyticsFixture.completionCount == 7)
        precondition(analyticsFixture.abandonedCount == 1)
        precondition(analyticsFixture.totalFocus == 10_500)
        precondition(analyticsFixture.activeDays == 7)
        precondition(analyticsFixture.currentStreak == 7)
        precondition(analyticsFixture.longestStreak == 7)
        precondition(TitleProfile.resolve("漫游").group == .exploration)
        precondition(TitleMastery.resolve(duration: 2 * 3_600) == .sprout)
        let completedExploration = HistoryFilter(group: .exploration, status: .completed)
        precondition(completedExploration.matches(streakSessions[0]))
        precondition(!completedExploration.matches(abandonedFixture))

        let importedScale = fixtureSession(
            title: "课业",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 9))!,
            duration: 11_427 * 60,
            status: .completed
        )
        let importedScaleAnalytics = FocusAnalyticsSnapshot(sessions: [importedScale], calendar: calendar)
        precondition(importedScaleAnalytics.level == 39)
        precondition(importedScaleAnalytics.experienceToNextLevel == 273)

        let crossYear = [
            fixtureSession(
                title: "高数",
                date: calendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 9))!,
                duration: 1_500,
                status: .completed
            ),
            fixtureSession(
                title: "高数",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 9))!,
                duration: 1_500,
                status: .completed
            )
        ]
        precondition(FocusAnalyticsSnapshot(sessions: crossYear, calendar: calendar).longestStreak == 2)
        precondition(FocusAnalyticsSnapshot(sessions: [], calendar: calendar).level == 1)
        print("focus-analytics-achievements-filters=pass")

        let primaryScreen = IslandScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 24, width: 1_440, height: 852),
            safeAreaTop: 32,
            displayID: "primary"
        )
        for placement in IslandPlacement.allCases {
            for presentation in [
                IslandPanelPresentation.idle,
                .compact,
                .expanded
            ] {
                let size = IslandPanelGeometry.size(
                    for: presentation,
                    hasNotch: primaryScreen.hasNotch,
                    placement: placement
                )
                let frame = IslandPanelGeometry.frame(
                    placement: placement,
                    screen: primaryScreen,
                    size: size,
                    offset: .zero
                )
                let bounds = IslandPanelGeometry.movementBounds(
                    for: placement,
                    screen: primaryScreen
                )
                precondition(frame.minX >= bounds.minX)
                precondition(frame.minY >= bounds.minY)
                precondition(frame.maxX <= bounds.maxX)
                precondition(frame.maxY <= bounds.maxY)
                if presentation == .expanded {
                    precondition(size.width >= 470, "Expanded island content must not clip")
                }
            }
        }
        let secondaryScreen = IslandScreenGeometry(
            frame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080),
            visibleFrame: CGRect(x: 1_440, y: 0, width: 1_920, height: 1_056),
            safeAreaTop: 0,
            displayID: "secondary"
        )
        let secondarySize = IslandPanelGeometry.size(
            for: .expanded,
            hasNotch: false,
            placement: .topTrailing
        )
        let secondaryFrame = IslandPanelGeometry.frame(
            placement: .topTrailing,
            screen: secondaryScreen,
            size: secondarySize,
            offset: CGSize(width: -40, height: -20)
        )
        let roundTripOffset = IslandPanelGeometry.offset(
            for: secondaryFrame,
            placement: .topTrailing,
            screen: secondaryScreen
        )
        precondition(abs(roundTripOffset.width + 40) < 0.001)
        precondition(abs(roundTripOffset.height + 20) < 0.001)
        let oversized = CGRect(x: -10_000, y: 10_000, width: 500, height: 74)
        let clamped = IslandPanelGeometry.clamped(oversized, to: secondaryScreen.visibleFrame)
        precondition(clamped.minX == secondaryScreen.visibleFrame.minX)
        precondition(clamped.maxY == secondaryScreen.visibleFrame.maxY)
        print("island-panel-geometry=pass")

        let accumulationNow = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)
        )!
        let accumulationSessions = [
            fixtureSession(
                title: "课业",
                date: calendar.date(from: DateComponents(year: 2025, month: 12, day: 30, hour: 9))!,
                duration: 3_600,
                status: .completed
            ),
            fixtureSession(
                title: "课业",
                date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 9))!,
                duration: 2 * 3_600,
                status: .completed
            ),
            fixtureSession(
                title: "开发",
                date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 9))!,
                duration: 1_800,
                status: .completed
            )
        ]
        let accumulationAnalytics = FocusAnalyticsSnapshot(
            sessions: accumulationSessions,
            now: accumulationNow,
            calendar: calendar
        )
        precondition(accumulationAnalytics.currentYearFocus == 9_000)
        precondition(accumulationAnalytics.currentYearActiveDays == 2)
        precondition(accumulationAnalytics.recentFocus == 1_800)
        precondition(accumulationAnalytics.recentMonths.count == 12)
        precondition(accumulationAnalytics.recentMonths.suffix(3).map(\.duration) == [7_200, 0, 1_800])
        precondition(accumulationAnalytics.latestUnlockedAchievement?.id == "first")
        precondition(accumulationAnalytics.nextAchievement?.id == "25h")

        let thresholdDate = calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 7, hour: 9)
        )!
        let thresholdBase = fixtureSession(
            title: "课业",
            date: thresholdDate,
            duration: 199 * 3_600 + 55 * 60,
            status: .completed
        )
        let thresholdCrossing = fixtureSession(
            title: "课业",
            date: thresholdDate.addingTimeInterval(24 * 3_600),
            duration: 10 * 60,
            status: .completed
        )
        let thresholdBefore = FocusAnalyticsSnapshot(
            sessions: [thresholdBase],
            now: accumulationNow,
            calendar: calendar
        )
        let thresholdAfter = FocusAnalyticsSnapshot(
            sessions: [thresholdBase, thresholdCrossing],
            now: accumulationNow,
            calendar: calendar
        )
        let receipt = FocusCompletionReceipt.make(
            focusedDuration: 10 * 60,
            taskTitle: "课业",
            before: thresholdBefore,
            after: thresholdAfter
        )
        precondition(receipt.focusedDuration == 10 * 60)
        precondition(receipt.taskTotal == 200 * 3_600 + 5 * 60)
        precondition(receipt.overallTotal == 200 * 3_600 + 5 * 60)
        precondition(receipt.completionCount == 2)
        precondition(receipt.unlockedAchievement?.id == "200h")
        precondition(receipt.nextAchievement?.id == "100sessions")
        print("accumulation-projections-receipt=pass")

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

        let presentationProject = FocusProject(
            id: UUID(),
            title: "学业主线",
            symbol: "graduationcap.fill",
            sortOrder: 0
        )
        let laterProject = FocusProject(
            id: UUID(),
            title: "创造实践",
            symbol: "hammer.fill",
            sortOrder: 1
        )
        let presentationTasks = (0..<8).map {
            FocusTask(
                projectID: presentationProject.id,
                title: "任务 \($0)",
                category: presentationProject.title,
                sortOrder: $0
            )
        } + [
            FocusTask(
                title: "未分类任务",
                category: "未分类",
                sortOrder: 9
            )
        ]
        let presentationGroups = TodayTaskPresentation.groups(
            projects: [laterProject, presentationProject],
            tasks: presentationTasks
        )
        precondition(presentationGroups.map(\.id) == [
            .project(presentationProject.id),
            .ungrouped
        ])
        precondition(presentationGroups.last?.title == "未分类")
        precondition(
            TodayTaskPresentation.defaultExpandedGroupID(
                groups: presentationGroups,
                preferredTaskID: presentationTasks[3].id
            ) == .project(presentationProject.id)
        )
        precondition(
            TodayTaskPresentation.visibleTasks(
                in: presentationGroups[0],
                showingAll: false
            ).count == 6
        )
        precondition(
            TodayTaskPresentation.remainingCount(
                in: presentationGroups[0],
                showingAll: false
            ) == 2
        )
        print("today-task-presentation=pass")

        let movementDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MossMoveTask-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(
            at: movementDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: movementDirectory) }
        let movementURL = movementDirectory.appendingPathComponent("moss-data.json")
        let movementStore = DataStore(fileURL: movementURL, seedIfMissing: false)
        let sourceProject = FocusProject(title: "来源", sortOrder: 0)
        let targetProject = FocusProject(title: "目标", sortOrder: 1)
        movementStore.addProject(sourceProject)
        movementStore.addProject(targetProject)
        let targetExisting = FocusTask(
            projectID: targetProject.id,
            title: "已有",
            category: targetProject.title,
            sortOrder: 4
        )
        let movingTask = FocusTask(
            projectID: sourceProject.id,
            title: "待移动",
            category: sourceProject.title,
            sortOrder: 1
        )
        movementStore.addTask(targetExisting)
        movementStore.addTask(movingTask)
        let historicalSession = FocusSession(
            taskID: movingTask.id,
            taskTitle: movingTask.title,
            projectID: sourceProject.id,
            projectTitle: sourceProject.title,
            category: sourceProject.title,
            startedAt: .now,
            plannedDuration: 1_500,
            warmupDuration: 0,
            timerActivity: .pomodoro,
            mode: .standard
        )
        movementStore.addSession(historicalSession)
        precondition(movementStore.moveTask(id: movingTask.id, toProjectID: targetProject.id))
        precondition(
            movementStore.tasks.first(where: { $0.id == movingTask.id })?.projectID
                == targetProject.id
        )
        precondition(
            movementStore.tasks.first(where: { $0.id == movingTask.id })?.category
                == targetProject.title
        )
        precondition(
            movementStore.tasks.first(where: { $0.id == movingTask.id })?.sortOrder == 5
        )
        precondition(movementStore.sessions.first?.projectID == sourceProject.id)
        precondition(!movementStore.moveTask(id: movingTask.id, toProjectID: targetProject.id))
        let reloadedMovementStore = DataStore(fileURL: movementURL, seedIfMissing: false)
        precondition(
            reloadedMovementStore.tasks.first(where: { $0.id == movingTask.id })?.projectID
                == targetProject.id
        )
        precondition(movementStore.moveTask(id: movingTask.id, toProjectID: sourceProject.id))
        var archivedTarget = targetProject
        archivedTarget.archived = true
        movementStore.updateProject(archivedTarget)
        precondition(!movementStore.moveTask(id: movingTask.id, toProjectID: archivedTarget.id))
        precondition(
            movementStore.tasks.first(where: { $0.id == movingTask.id })?.projectID
                == sourceProject.id
        )
        precondition(!movementStore.moveTask(id: movingTask.id, toProjectID: UUID()))
        precondition(movementStore.moveTask(id: movingTask.id, toProjectID: nil))
        precondition(
            movementStore.tasks.first(where: { $0.id == movingTask.id })?.category
                == "未分类"
        )
        print("task-project-movement=pass")

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
        lifecycleStore.archiveTask(id: archivedChild.id, archived: true)
        lifecycleStore.restoreTask(id: archivedChild.id)
        precondition(
            lifecycleStore.projects.first(where: { $0.id == archivedProject.id })?.archived == false
        )
        precondition(
            lifecycleStore.tasks.first(where: { $0.id == archivedChild.id })?.archived == false
        )
        print("archived-project-task-filter=pass")

        let noticeStore = AppStore()
        noticeStore.showTransient("重复提示", duration: .milliseconds(80))
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        noticeStore.showTransient("重复提示", duration: .milliseconds(180))
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        precondition(noticeStore.transientNotice?.message == "重复提示")
        RunLoop.main.run(until: Date().addingTimeInterval(0.14))
        precondition(noticeStore.transientNotice == nil)
        print("transient-notice-identity=pass")

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
        precondition(appStore.completionReceipt?.focusedDuration ?? 0 > 0)
        precondition(appStore.completionReceipt?.taskTitle == lifecycleTask.title)
        precondition(appStore.completionReceipt?.overallTotal ?? 0 > 0)
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

        var autoCompletionTask = lifecycleTask
        autoCompletionTask.id = UUID()
        autoCompletionTask.title = "Automatic completion"
        autoCompletionTask.timerActivityRaw = TimerActivity.countdown.rawValue
        autoCompletionTask.focusDuration = 1
        autoCompletionTask.warmupDuration = 0
        autoCompletionTask.discardThreshold = 0
        lifecycleStore.addTask(autoCompletionTask)
        standardDefaults.removeObject(forKey: v2Key)
        let autoCompletionStore = AppStore()
        autoCompletionStore.configure(with: lifecycleStore)
        precondition(!autoCompletionStore.mainWindowRequested)
        autoCompletionStore.start(task: autoCompletionTask)
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        precondition(autoCompletionStore.phase == .awaitingReview)
        precondition(!autoCompletionStore.mainWindowRequested)
        precondition(!autoCompletionStore.isReviewPresented)
        autoCompletionStore.presentReview()
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        precondition(autoCompletionStore.mainWindowRequested)
        precondition(autoCompletionStore.isReviewPresented)
        autoCompletionStore.finishReview(
            completion: .partial,
            blocker: .none,
            distraction: .none,
            note: ""
        )
        print("automatic-completion-review-presentation=pass")

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

        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MossBehaviorCheck-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: storageDirectory) }
        let primaryURL = storageDirectory.appendingPathComponent("moss-data.json")
        let corruptData = Data("{not valid json".utf8)
        try! corruptData.write(to: primaryURL)
        let recoveryProject = FocusProject(title: "Recovered project")
        let recoveryTask = FocusTask(
            projectID: recoveryProject.id,
            title: "Recovered task",
            category: recoveryProject.title
        )
        let recoveryDatabase = MossDatabase(
            projects: [recoveryProject],
            tasks: [recoveryTask]
        )
        let storageEncoder = JSONEncoder()
        storageEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        storageEncoder.dateEncodingStrategy = .iso8601
        try! storageEncoder.encode(recoveryDatabase).write(
            to: DataStore.backupURL(for: primaryURL),
            options: .atomic
        )
        let recoveryStore = DataStore(fileURL: primaryURL, seedIfMissing: true)
        precondition(recoveryStore.storageIssue?.kind == .unreadable)
        precondition(recoveryStore.storageIssue?.canRestoreBackup == true)
        precondition(try! Data(contentsOf: primaryURL) == corruptData)
        precondition(recoveryStore.tasks.isEmpty)
        recoveryStore.restoreBackup()
        precondition(recoveryStore.tasks.first?.id == recoveryTask.id)
        precondition(recoveryStore.storageIssue?.kind == .recovered)
        let recoveredData = try! Data(contentsOf: primaryURL)
        let storageDecoder = JSONDecoder()
        storageDecoder.dateDecodingStrategy = .iso8601
        let recoveredDatabase = try! storageDecoder.decode(
            MossDatabase.self,
            from: recoveredData
        )
        precondition(recoveredDatabase.tasks.first?.id == recoveryTask.id)
        let preservedCorruptFiles = try! FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains(".corrupt-") }
        precondition(preservedCorruptFiles.count == 1)
        print("corrupt-storage-recovery=pass")

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
        let exportSession = fixtureSession(
            title: exportTask.title,
            date: .now,
            duration: 1_500,
            status: .completed
        )
        let exportInterruption = Interruption(
            sessionID: exportSession.id,
            reason: .phone
        )
        let exportReflection = Reflection(
            sessionID: exportSession.id,
            blockerType: .difficult,
            freeText: "需要拆小"
        )
        let exportSnapshot = DailySnapshot(
            id: UUID(),
            date: .now,
            totalFocusDuration: 1_500,
            sessionsCompleted: 1,
            startFriction: 20,
            interruptionRate: 0.2,
            planAccuracy: 0.9,
            topCategory: exportProject.title,
            generatedSummary: "稳定推进"
        )
        let exportData = try! ExportService.jsonData(
            projects: [exportProject],
            tasks: [exportTask],
            sessions: [exportSession],
            interruptions: [exportInterruption],
            reflections: [exportReflection],
            snapshots: [exportSnapshot]
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try! decoder.decode(MossExport.self, from: exportData)
        precondition(payload.projects.first?.symbol == "shippingbox.fill")
        precondition(payload.projects.first?.archived == true)
        precondition(payload.tasks.first?.breakDuration == 20 * 60)
        precondition(payload.sessions.count == 1)
        precondition(payload.interruptions.first?.reasonRaw == InterruptionReason.phone.rawValue)
        precondition(payload.reflections.first?.freeText == "需要拆小")
        precondition(payload.snapshots.first?.generatedSummary == "稳定推进")
        print("json-export-roundtrip=pass")
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func fixtureSession(
        title: String,
        date: Date,
        duration: TimeInterval,
        status: SessionStatus
    ) -> FocusSession {
        var session = FocusSession(
            taskID: UUID(),
            taskTitle: title,
            projectID: nil,
            projectTitle: TitleProfile.resolve(title).group.title,
            category: TitleProfile.resolve(title).group.title,
            startedAt: date,
            plannedDuration: duration,
            warmupDuration: 0,
            timerActivity: .pomodoro,
            mode: .standard
        )
        session.endedAt = date.addingTimeInterval(duration)
        session.actualFocusDuration = duration
        session.statusRaw = status.rawValue
        return session
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
