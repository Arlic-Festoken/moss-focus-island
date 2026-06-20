import AppKit
import Combine
import Foundation

enum FocusPhase: String, Codable {
    case idle
    case focusing
    case paused
    case breakTime
    case awaitingReview
}

struct PersistedRun: Codable {
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
    @Published private(set) var currentTaskTitle = ""
    @Published private(set) var currentCategory = ""
    @Published private(set) var plannedDuration: TimeInterval = 25 * 60
    @Published var isIslandExpanded = false
    @Published var isReviewPresented = false
    @Published var interruptionNeedsReason = false
    @Published var wakeGapMessage: String?
    @Published var transientMessage: String?

    private(set) var dataStore: DataStore?
    private var timer: Timer?
    private var run: PersistedRun?
    private var activeInterruptionID: UUID?
    private var lastTick = Date()

    private let defaults = UserDefaults.standard
    private let runKey = "moss.activeRun.v1"

    var isActive: Bool {
        phase == .focusing || phase == .paused || phase == .breakTime
    }

    var progress: Double {
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
        if phase == .focusing || phase == .breakTime {
            startTimer()
        }
    }

    func start(task: FocusTask, mode: FocusMode = .standard, duration: TimeInterval? = nil) {
        guard phase == .idle else {
            showTransient("先结束当前专注段")
            return
        }
        guard let dataStore else { return }

        let configuredMinutes = defaults.object(forKey: "focusMinutes") as? Int ?? 25
        let selectedDuration = duration ?? {
            switch mode {
            case .ignition: return 5 * 60
            case .standard: return TimeInterval(configuredMinutes * 60)
            case .free: return TimeInterval(configuredMinutes * 60)
            }
        }()
        let session = FocusSession(
            taskID: task.id,
            taskTitle: task.title,
            category: task.category,
            plannedDuration: selectedDuration,
            mode: mode
        )
        dataStore.addSession(session)

        let newRun = PersistedRun(
            phase: .focusing,
            sessionID: session.id,
            taskID: task.id,
            taskTitle: task.title,
            category: task.category,
            startedAt: .now,
            plannedDuration: selectedDuration,
            accumulatedPausedDuration: 0,
            pauseStartedAt: nil,
            mode: mode,
            focusEndedAt: nil,
            breakStartedAt: nil,
            breakDuration: 5 * 60
        )
        apply(newRun)
        persistRun()
        startTimer()
        showTransient(mode == .ignition ? "先做五分钟，别和自己谈判" : "专注开始")
    }

    func startLastTask() {
        guard let dataStore else { return }
        let sessions = dataStore.sessions.sorted { $0.startedAt > $1.startedAt }
        let tasks = dataStore.tasks
        let preferred = sessions.first.flatMap { session in
            tasks.first { $0.id == session.taskID && !$0.archived }
        } ?? tasks.filter { !$0.archived }.sorted { $0.sortOrder < $1.sortOrder }.first
        if let preferred {
            start(task: preferred)
        } else {
            showTransient("先在主页添加一个任务")
            openMainWindow()
        }
    }

    func pause() {
        guard var current = run, phase == .focusing else { return }
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
        current.phase = .focusing
        apply(current)
        updateSessionStatus(.active)
        persistRun()
        startTimer()
    }

    func requestEnd() {
        guard phase == .focusing || phase == .paused else { return }
        phase = .awaitingReview
        run?.phase = .awaitingReview
        run?.focusEndedAt = .now
        updateClock()
        persistRun()
        stopTimer()
        openMainWindow()
        isReviewPresented = true
    }

    func cancelReview() {
        guard var current = run, phase == .awaitingReview else { return }
        current.phase = current.pauseStartedAt == nil ? .focusing : .paused
        current.focusEndedAt = nil
        apply(current)
        isReviewPresented = false
        persistRun()
        if current.phase == .focusing {
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

        isReviewPresented = false
        showTransient("+\(focused.compactDuration) 已记录")
        if completion == .completed {
            startBreak()
            return
        }
        clearToIdle()
    }

    func beginOrReturnFromInterruption() {
        guard let current = run, phase == .focusing || phase == .paused,
              let dataStore else { return }
        if activeInterruptionID == nil {
            let interruption = Interruption(sessionID: current.sessionID)
            dataStore.addInterruption(interruption)
            activeInterruptionID = interruption.id
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
        interruptionNeedsReason = false
        showTransient("欢迎回来")
    }

    func startBreak() {
        guard var current = run else { return }
        let configuredMinutes = defaults.object(forKey: "breakMinutes") as? Int ?? 5
        current.phase = .breakTime
        current.breakStartedAt = .now
        current.breakDuration = TimeInterval(configuredMinutes * 60)
        apply(current)
        persistRun()
        startTimer()
    }

    func skipBreak() {
        clearToIdle()
    }

    func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApplication.shared.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
        }
    }

    func showTransient(_ message: String) {
        transientMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if transientMessage == message {
                transientMessage = nil
            }
        }
    }

    private func apply(_ current: PersistedRun) {
        run = current
        phase = current.phase
        plannedDuration = current.phase == .breakTime ? current.breakDuration : current.plannedDuration
        currentTaskTitle = current.taskTitle
        currentCategory = current.category
        updateClock()
    }

    private func calculatedElapsed(for current: PersistedRun, at date: Date = .now) -> TimeInterval {
        let end = current.pauseStartedAt ?? current.focusEndedAt ?? date
        return max(0, end.timeIntervalSince(current.startedAt) - current.accumulatedPausedDuration)
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
            if remaining <= 0 { skipBreak() }
            return
        }
        elapsed = calculatedElapsed(for: current)
        remaining = max(0, current.plannedDuration - elapsed)
        if remaining <= 0, current.phase == .focusing {
            phase = .awaitingReview
            run?.phase = .awaitingReview
            run?.focusEndedAt = .now
            persistRun()
            stopTimer()
            openMainWindow()
            isReviewPresented = true
            if defaults.object(forKey: "subtleSound") as? Bool ?? true {
                NSSound(named: "Glass")?.play()
            }
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
        guard let data = defaults.data(forKey: runKey),
              let restored = try? JSONDecoder().decode(PersistedRun.self, from: data) else {
            return
        }
        apply(restored)
        isReviewPresented = restored.phase == .awaitingReview
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
        currentTaskTitle = ""
        currentCategory = ""
    }

    private func updateSessionStatus(_ status: SessionStatus) {
        guard let id = run?.sessionID, let dataStore else { return }
        dataStore.updateSession(id: id) { session in
            session.statusRaw = status.rawValue
        }
    }
}
