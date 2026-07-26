import AppKit
import Combine
import Foundation

@MainActor
enum MainWindowRouter {
    static var open: (() -> Void)?
}

enum FocusPhase: String, Codable {
    case idle
    case preparing
    case focusing
    case paused
    case breakTime
    case awaitingReview
}

struct TransientNotice: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

struct PersistedRun: Codable {
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
    var activeInterruptionID: UUID?
    var focusEndedAt: Date?
    var breakStartedAt: Date?
    var breakDuration: TimeInterval
}

private struct LegacyPersistedRunV1: Codable {
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

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var phase: FocusPhase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var warmupRemaining: TimeInterval = 0
    @Published private(set) var currentTaskTitle = ""
    @Published private(set) var currentCategory = ""
    @Published private(set) var currentProjectTitle = ""
    @Published private(set) var plannedDuration: TimeInterval = 25 * 60
    @Published private(set) var timerActivity: TimerActivity = .pomodoro
    @Published var isIslandExpanded = false
    @Published var isReviewPresented = false
    @Published var interruptionNeedsReason = false
    @Published var wakeGapMessage: String?
    @Published private(set) var transientNotice: TransientNotice?
    @Published private(set) var completionReceipt: FocusCompletionReceipt?
    @Published private(set) var mainWindowRequested: Bool

    private(set) var dataStore: DataStore?
    private var timer: Timer?
    private var run: PersistedRun?
    private var activeInterruptionID: UUID?
    private var lastTick = Date()

    private let defaults = UserDefaults.standard
    private let runKey = "moss.activeRun.v2"

    init() {
        let launchSilently = (UserDefaults.standard.object(forKey: "launchSilently") as? Bool) ?? true
        mainWindowRequested = !launchSilently
    }

    var isActive: Bool {
        phase == .preparing || phase == .focusing || phase == .paused || phase == .breakTime
    }

    var isPreparing: Bool { phase == .preparing }

    var currentTaskID: UUID? {
        run?.taskID
    }

    var currentProjectID: UUID? {
        run?.projectID
    }

    var displayTime: TimeInterval {
        if phase == .preparing { return warmupRemaining }
        if phase == .breakTime { return remaining }
        return timerActivity.countsDown ? remaining : elapsed
    }

    var timerDirectionLabel: String {
        if phase == .preparing { return "进入状态" }
        if phase == .breakTime { return "休息" }
        return timerActivity.countsDown ? "剩余" : "已专注"
    }

    var progress: Double {
        if phase == .preparing, let run, run.warmupDuration > 0 {
            return min(1, max(0, 1 - warmupRemaining / run.warmupDuration))
        }
        guard plannedDuration > 0 else { return 0 }
        return min(1, max(0, elapsed / plannedDuration))
    }

    var todayCompletedCount: Int {
        guard let dataStore else { return 0 }
        return dataStore.sessions.filter {
            $0.startedAt >= Date.now.dayStart && $0.status == .completed
        }.count
    }

    func configure(with dataStore: DataStore) {
        guard self.dataStore == nil else { return }
        self.dataStore = dataStore
        restoreRunIfNeeded()
        observeSystemEvents()
        if phase == .preparing || phase == .focusing || phase == .breakTime {
            startTimer()
        }
    }

    func start(task: FocusTask, mode: FocusMode = .standard, duration: TimeInterval? = nil) {
        guard phase == .idle else {
            showTransient("先结束当前专注段")
            return
        }
        guard let dataStore else { return }

        let selectedActivity: TimerActivity = mode == .ignition ? .countdown : task.timerActivity
        let selectedDuration = duration ?? (mode == .ignition ? 5 * 60 : task.focusDuration)
        let project = dataStore.project(id: task.projectID)
        let projectTitle = project?.title ?? task.category
        let session = FocusSession(
            taskID: task.id,
            taskTitle: task.title,
            projectID: task.projectID,
            projectTitle: projectTitle,
            category: projectTitle,
            plannedDuration: selectedDuration,
            warmupDuration: task.warmupDuration,
            timerActivity: selectedActivity,
            mode: mode
        )
        dataStore.addSession(session)

        let newRun = PersistedRun(
            phase: task.warmupDuration > 0 ? .preparing : .focusing,
            sessionID: session.id,
            taskID: task.id,
            taskTitle: task.title,
            projectID: task.projectID,
            projectTitle: projectTitle,
            category: projectTitle,
            startedAt: .now,
            plannedDuration: selectedDuration,
            warmupDuration: task.warmupDuration,
            discardThreshold: task.discardThreshold,
            accumulatedPausedDuration: 0,
            pauseStartedAt: nil,
            mode: mode,
            timerActivity: selectedActivity,
            activeInterruptionID: nil,
            focusEndedAt: nil,
            breakStartedAt: nil,
            breakDuration: task.breakDuration
        )
        apply(newRun)
        persistRun()
        startTimer()
        showTransient(task.warmupDuration > 0 ? "先进入状态，计时稍后开始" : "专注开始")
    }

    func startLastTask() {
        guard let dataStore else { return }
        if let preferred = dataStore.preferredStartTask {
            start(task: preferred)
        } else {
            showTransient("先在主页添加一个任务")
            openMainWindow()
        }
    }

    func pause() {
        guard var current = run, phase == .preparing || phase == .focusing else { return }
        current.phase = .paused
        current.pauseStartedAt = .now
        apply(current)
        updateSessionStatus(.paused)
        persistRun()
        stopTimer()
    }

    func resume() {
        guard var current = run, phase == .paused else { return }
        if let pausedAt = current.pauseStartedAt {
            current.accumulatedPausedDuration += Date.now.timeIntervalSince(pausedAt)
        }
        current.pauseStartedAt = nil
        current.focusEndedAt = nil
        current.phase = activeWallElapsed(for: current) < current.warmupDuration ? .preparing : .focusing
        apply(current)
        updateSessionStatus(.active)
        persistRun()
        startTimer()
    }

    func requestEnd() {
        if phase == .preparing {
            cancelStart()
            return
        }
        guard phase == .focusing || phase == .paused else { return }
        guard let current = run, let dataStore else { return }

        if calculatedElapsed(for: current) < current.discardThreshold {
            dataStore.removeSession(id: current.sessionID)
            clearToIdle()
            showTransient("未满 \(Int(current.discardThreshold / 60)) 分钟，本次不计入")
            return
        }

        enterAwaitingReview(automatically: false)
    }

    func cancelStart() {
        guard phase == .preparing, let sessionID = run?.sessionID else { return }
        dataStore?.removeSession(id: sessionID)
        clearToIdle()
        showTransient("已取消，本次未计时")
    }

    func cancelReview() {
        guard var current = run, phase == .awaitingReview else { return }
        if current.pauseStartedAt == nil, let reviewStartedAt = current.focusEndedAt {
            current.accumulatedPausedDuration += Date.now.timeIntervalSince(reviewStartedAt)
        }
        current.focusEndedAt = nil
        if current.pauseStartedAt != nil {
            current.phase = .paused
        } else {
            current.phase = activeWallElapsed(for: current) < current.warmupDuration ? .preparing : .focusing
        }
        apply(current)
        isReviewPresented = false
        persistRun()
        if current.phase != .paused {
            startTimer()
        }
    }

    func finishReview(
        completion: CompletionState,
        blocker: BlockerType,
        distraction: DistractionSource,
        note: String
    ) {
        guard let current = run, let dataStore else { return }
        let before = FocusAnalyticsSnapshot(sessions: dataStore.sessions)
        if let interruptionID = activeInterruptionID {
            dataStore.updateInterruption(id: interruptionID) { interruption in
                interruption.endedAt = .now
                interruption.reasonRaw = InterruptionReason.other.rawValue
                interruption.returnedToSameTask = false
            }
            activeInterruptionID = nil
            run?.activeInterruptionID = nil
            interruptionNeedsReason = false
        }
        let focused = calculatedElapsed(for: current)
        dataStore.updateSession(id: current.sessionID) { session in
            session.endedAt = .now
            session.actualFocusDuration = focused
            session.pausedDuration = current.accumulatedPausedDuration + currentPauseDuration(for: current)
            session.statusRaw = SessionStatus.completed.rawValue
            session.completionStateRaw = completion.rawValue
            session.distractionSourceRaw = distraction.rawValue
            session.note = note
        }
        if blocker != .none || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dataStore.addReflection(Reflection(
                sessionID: current.sessionID,
                blockerType: blocker,
                freeText: note
            ))
        }
        if completion == .completed {
            dataStore.incrementCompletedSessions(taskID: current.taskID)
        }
        let after = FocusAnalyticsSnapshot(sessions: dataStore.sessions)
        showCompletionReceipt(
            FocusCompletionReceipt.make(
                focusedDuration: focused,
                taskTitle: current.taskTitle,
                before: before,
                after: after
            )
        )

        isReviewPresented = false
        showTransient("+\(focused.compactDuration) 已记录")
        if current.timerActivity == .pomodoro {
            startBreak()
        } else {
            clearToIdle()
        }
    }

    func beginOrReturnFromInterruption() {
        guard let current = run,
              phase == .preparing || phase == .focusing || phase == .paused,
              let dataStore else { return }
        if activeInterruptionID == nil {
            let interruption = Interruption(sessionID: current.sessionID)
            dataStore.addInterruption(interruption)
            activeInterruptionID = interruption.id
            run?.activeInterruptionID = interruption.id
            persistRun()
            interruptionNeedsReason = false
            showTransient("已记下这次打断，回来再点一下")
        } else {
            interruptionNeedsReason = true
        }
    }

    func finishInterruption(reason: InterruptionReason, returned: Bool = true) {
        guard let id = activeInterruptionID, let dataStore else { return }
        dataStore.updateInterruption(id: id) { interruption in
            interruption.endedAt = .now
            interruption.reasonRaw = reason.rawValue
            interruption.returnedToSameTask = returned
        }
        activeInterruptionID = nil
        run?.activeInterruptionID = nil
        persistRun()
        interruptionNeedsReason = false
        showTransient("欢迎回来")
    }

    func startBreak() {
        guard var current = run else { return }
        current.phase = .breakTime
        current.breakStartedAt = .now
        apply(current)
        persistRun()
        startTimer()
    }

    func skipBreak() {
        clearToIdle()
    }

    func openMainWindow() {
        mainWindowRequested = true
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: {
                $0.title == "Moss · 专注岛" && !($0 is NSPanel)
            }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                MainWindowRouter.open?()
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    func presentReview() {
        guard phase == .awaitingReview else { return }
        openMainWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.phase == .awaitingReview else { return }
            self.isReviewPresented = true
        }
    }

    func showTransient(_ message: String) {
        let notice = TransientNotice(message: message)
        transientNotice = notice
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard let self else { return }
            if self.transientNotice?.id == notice.id {
                self.transientNotice = nil
            }
        }
    }

    private func showCompletionReceipt(_ receipt: FocusCompletionReceipt) {
        completionReceipt = receipt
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.8))
            guard let self else { return }
            if self.completionReceipt?.id == receipt.id {
                self.completionReceipt = nil
            }
        }
    }

    private func enterAwaitingReview(automatically: Bool) {
        guard phase == .focusing || phase == .paused else { return }
        phase = .awaitingReview
        run?.phase = .awaitingReview
        run?.focusEndedAt = .now
        updateClock()
        persistRun()
        stopTimer()
        isIslandExpanded = true

        if automatically {
            showTransient("本段已完成，点击后补充记录")
            if defaults.object(forKey: "subtleSound") as? Bool ?? true {
                NSSound(named: "Glass")?.play()
            }
        } else {
            presentReview()
        }
    }

    private func apply(_ current: PersistedRun) {
        run = current
        phase = current.phase
        plannedDuration = current.phase == .breakTime ? current.breakDuration : current.plannedDuration
        timerActivity = current.timerActivity
        currentTaskTitle = current.taskTitle
        currentCategory = current.category
        currentProjectTitle = current.projectTitle
        activeInterruptionID = current.activeInterruptionID
        updateClock()
    }

    private func activeWallElapsed(for current: PersistedRun, at date: Date = .now) -> TimeInterval {
        let end = current.pauseStartedAt ?? current.focusEndedAt ?? date
        return max(0, end.timeIntervalSince(current.startedAt) - current.accumulatedPausedDuration)
    }

    private func calculatedElapsed(for current: PersistedRun, at date: Date = .now) -> TimeInterval {
        max(0, activeWallElapsed(for: current, at: date) - current.warmupDuration)
    }

    private func currentPauseDuration(for current: PersistedRun) -> TimeInterval {
        guard let pausedAt = current.pauseStartedAt else { return 0 }
        return Date.now.timeIntervalSince(pausedAt)
    }

    private func updateClock() {
        guard let current = run else { return }
        if current.phase == .breakTime, let breakStart = current.breakStartedAt {
            elapsed = max(0, Date.now.timeIntervalSince(breakStart))
            remaining = max(0, current.breakDuration - elapsed)
            warmupRemaining = 0
            if remaining <= 0 { skipBreak() }
            return
        }

        let wallElapsed = activeWallElapsed(for: current)
        warmupRemaining = max(0, current.warmupDuration - wallElapsed)
        elapsed = calculatedElapsed(for: current)

        if current.phase != .paused && current.phase != .awaitingReview {
            let expectedPhase: FocusPhase = warmupRemaining > 0 ? .preparing : .focusing
            if phase != expectedPhase {
                phase = expectedPhase
                run?.phase = expectedPhase
                persistRun()
            }
        }

        if current.timerActivity.countsDown {
            remaining = max(0, current.plannedDuration - elapsed)
            if remaining <= 0 && phase == .focusing {
                enterAwaitingReview(automatically: true)
            }
        } else {
            remaining = current.plannedDuration > 0
                ? max(0, current.plannedDuration - elapsed)
                : 0
        }
    }

    private func startTimer() {
        timer?.invalidate()
        lastTick = .now
        let next = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let gap = Date.now.timeIntervalSince(self.lastTick)
                if gap > 90, self.isActive {
                    self.wakeGapMessage = "离开了 \(gap.compactDuration)，计时已按真实时间恢复"
                }
                self.lastTick = .now
                self.updateClock()
            }
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func observeSystemEvents() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateClock()
            }
        }
    }

    private func persistRun() {
        guard let run, let data = try? JSONEncoder().encode(run) else { return }
        defaults.set(data, forKey: runKey)
    }

    private func restoreRunIfNeeded() {
        if let data = defaults.data(forKey: runKey),
           let restored = try? JSONDecoder().decode(PersistedRun.self, from: data) {
            apply(restored)
            return
        }

        defaults.removeObject(forKey: runKey)
        let legacyKey = "moss.activeRun.v1"
        guard let data = defaults.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(LegacyPersistedRunV1.self, from: data) else {
            defaults.removeObject(forKey: legacyKey)
            return
        }

        let task = dataStore?.tasks.first { $0.id == legacy.taskID }
        let project = dataStore?.project(id: task?.projectID)
        let restored = PersistedRun(
            phase: legacy.phase,
            sessionID: legacy.sessionID,
            taskID: legacy.taskID,
            taskTitle: legacy.taskTitle,
            projectID: task?.projectID,
            projectTitle: project?.title ?? legacy.category,
            category: legacy.category,
            startedAt: legacy.startedAt,
            plannedDuration: legacy.plannedDuration,
            warmupDuration: 0,
            discardThreshold: 0,
            accumulatedPausedDuration: legacy.accumulatedPausedDuration,
            pauseStartedAt: legacy.pauseStartedAt,
            mode: legacy.mode,
            timerActivity: legacy.mode == .ignition ? .countdown : (task?.timerActivity ?? .pomodoro),
            activeInterruptionID: nil,
            focusEndedAt: legacy.focusEndedAt,
            breakStartedAt: legacy.breakStartedAt,
            breakDuration: legacy.breakDuration
        )
        apply(restored)
        persistRun()
        defaults.removeObject(forKey: legacyKey)
    }

    private func clearPersistedRun() {
        defaults.removeObject(forKey: runKey)
    }

    private func clearToIdle() {
        stopTimer()
        clearPersistedRun()
        run = nil
        phase = .idle
        remaining = 0
        elapsed = 0
        warmupRemaining = 0
        currentTaskTitle = ""
        currentCategory = ""
        currentProjectTitle = ""
        timerActivity = .pomodoro
        activeInterruptionID = nil
        interruptionNeedsReason = false
        isReviewPresented = false
    }

    private func updateSessionStatus(_ status: SessionStatus) {
        guard let id = run?.sessionID, let dataStore else { return }
        dataStore.updateSession(id: id) { session in
            session.statusRaw = status.rawValue
        }
    }
}
