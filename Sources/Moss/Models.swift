import Foundation

enum TimerActivity: String, Codable, CaseIterable, Identifiable {
    case pomodoro
    case countdown
    case stopwatch
    case infinite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pomodoro: "番茄钟"
        case .countdown: "倒计时"
        case .stopwatch: "正计时"
        case .infinite: "无限计时"
        }
    }

    var subtitle: String {
        switch self {
        case .pomodoro: "到点结束，完成后进入休息"
        case .countdown: "到点结束，不自动进入休息"
        case .stopwatch: "向上计时，可设置参考目标"
        case .infinite: "无目标限制，手动结束"
        }
    }

    var icon: String {
        switch self {
        case .pomodoro: "timer"
        case .countdown: "hourglass"
        case .stopwatch: "stopwatch"
        case .infinite: "infinity"
        }
    }

    var countsDown: Bool { self == .pomodoro || self == .countdown }
}

enum FocusMode: String, Codable, CaseIterable {
    case standard
    case ignition
    case free

    var title: String {
        switch self {
        case .standard: "标准专注"
        case .ignition: "五分钟点火"
        case .free: "自由专注"
        }
    }
}

enum SessionStatus: String, Codable {
    case active
    case paused
    case completed
    case abandoned
}

enum CompletionState: String, Codable, CaseIterable {
    case completed
    case partial
    case changed

    var title: String {
        switch self {
        case .completed: "完成"
        case .partial: "部分完成"
        case .changed: "任务变了"
        }
    }
}

enum BlockerType: String, Codable, CaseIterable {
    case none
    case unknown
    case difficult
    case environment

    var title: String {
        switch self {
        case .none: "没有"
        case .unknown: "不会"
        case .difficult: "太难"
        case .environment: "环境打断"
        }
    }
}

enum DistractionSource: String, Codable, CaseIterable {
    case none
    case phone
    case chat
    case fatigue
    case other

    var title: String {
        switch self {
        case .none: "无"
        case .phone: "手机"
        case .chat: "聊天"
        case .fatigue: "疲劳"
        case .other: "其他"
        }
    }
}

enum InterruptionReason: String, Codable, CaseIterable, Identifiable {
    case phone
    case wechat
    case roommate
    case meal
    case drifting
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phone: "手机"
        case .wechat: "微信"
        case .roommate: "室友"
        case .meal: "吃饭"
        case .drifting: "发呆"
        case .other: "其他"
        }
    }
}

struct FocusProject: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var symbol: String
    var archived: Bool
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        symbol: String = "folder.fill",
        archived: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.archived = archived
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

struct FocusTask: Identifiable, Codable, Hashable {
    var id: UUID
    var projectID: UUID?
    var title: String
    var category: String
    var estimatedSessions: Int
    var completedSessions: Int
    var archived: Bool
    var createdAt: Date
    var sortOrder: Int
    var timerActivityRaw: String
    var focusDuration: TimeInterval
    var breakDuration: TimeInterval
    var warmupDuration: TimeInterval
    var discardThreshold: TimeInterval

    init(
        id: UUID = UUID(),
        projectID: UUID? = nil,
        title: String,
        category: String,
        estimatedSessions: Int = 1,
        completedSessions: Int = 0,
        archived: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        timerActivity: TimerActivity = .pomodoro,
        focusDuration: TimeInterval = 25 * 60,
        breakDuration: TimeInterval = 5 * 60,
        warmupDuration: TimeInterval = 60,
        discardThreshold: TimeInterval = 120
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.category = category
        self.estimatedSessions = estimatedSessions
        self.completedSessions = completedSessions
        self.archived = archived
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.timerActivityRaw = timerActivity.rawValue
        self.focusDuration = focusDuration
        self.breakDuration = breakDuration
        self.warmupDuration = warmupDuration
        self.discardThreshold = discardThreshold
    }

    var timerActivity: TimerActivity {
        TimerActivity(rawValue: timerActivityRaw) ?? .pomodoro
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectID, title, category, estimatedSessions, completedSessions
        case archived, createdAt, sortOrder, timerActivityRaw, focusDuration
        case breakDuration, warmupDuration, discardThreshold
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        projectID = try values.decodeIfPresent(UUID.self, forKey: .projectID)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? "未命名任务"
        category = try values.decodeIfPresent(String.self, forKey: .category) ?? "未分类"
        estimatedSessions = try values.decodeIfPresent(Int.self, forKey: .estimatedSessions) ?? 1
        completedSessions = try values.decodeIfPresent(Int.self, forKey: .completedSessions) ?? 0
        archived = try values.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        sortOrder = try values.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        timerActivityRaw = try values.decodeIfPresent(String.self, forKey: .timerActivityRaw)
            ?? TimerActivity.pomodoro.rawValue
        focusDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .focusDuration) ?? 25 * 60
        breakDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .breakDuration) ?? 5 * 60
        warmupDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .warmupDuration) ?? 60
        discardThreshold = try values.decodeIfPresent(TimeInterval.self, forKey: .discardThreshold) ?? 120
    }
}

struct FocusSession: Identifiable, Codable, Hashable {
    var id: UUID
    var taskID: UUID
    var taskTitle: String
    var projectID: UUID?
    var projectTitle: String
    var category: String
    var startedAt: Date
    var endedAt: Date?
    var plannedDuration: TimeInterval
    var actualFocusDuration: TimeInterval
    var pausedDuration: TimeInterval
    var warmupDuration: TimeInterval
    var timerActivityRaw: String
    var modeRaw: String
    var statusRaw: String
    var completionStateRaw: String?
    var energyBefore: Int?
    var energyAfter: Int?
    var note: String
    var distractionSourceRaw: String?

    init(
        id: UUID = UUID(),
        taskID: UUID,
        taskTitle: String,
        projectID: UUID?,
        projectTitle: String,
        category: String,
        startedAt: Date = .now,
        plannedDuration: TimeInterval,
        warmupDuration: TimeInterval,
        timerActivity: TimerActivity,
        mode: FocusMode
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.projectID = projectID
        self.projectTitle = projectTitle
        self.category = category
        self.startedAt = startedAt
        self.endedAt = nil
        self.plannedDuration = plannedDuration
        self.actualFocusDuration = 0
        self.pausedDuration = 0
        self.warmupDuration = warmupDuration
        self.timerActivityRaw = timerActivity.rawValue
        self.modeRaw = mode.rawValue
        self.statusRaw = SessionStatus.active.rawValue
        self.completionStateRaw = nil
        self.energyBefore = nil
        self.energyAfter = nil
        self.note = ""
        self.distractionSourceRaw = nil
    }

    var mode: FocusMode { FocusMode(rawValue: modeRaw) ?? .standard }
    var status: SessionStatus { SessionStatus(rawValue: statusRaw) ?? .completed }
    var timerActivity: TimerActivity { TimerActivity(rawValue: timerActivityRaw) ?? .pomodoro }

    private enum CodingKeys: String, CodingKey {
        case id, taskID, taskTitle, projectID, projectTitle, category, startedAt
        case endedAt, plannedDuration, actualFocusDuration, pausedDuration
        case warmupDuration, timerActivityRaw, modeRaw, statusRaw
        case completionStateRaw, energyBefore, energyAfter, note, distractionSourceRaw
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        taskID = try values.decodeIfPresent(UUID.self, forKey: .taskID) ?? UUID()
        taskTitle = try values.decodeIfPresent(String.self, forKey: .taskTitle) ?? "已删除任务"
        projectID = try values.decodeIfPresent(UUID.self, forKey: .projectID)
        category = try values.decodeIfPresent(String.self, forKey: .category) ?? "未分类"
        projectTitle = try values.decodeIfPresent(String.self, forKey: .projectTitle) ?? category
        startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt) ?? .now
        endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
        plannedDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .plannedDuration) ?? 25 * 60
        actualFocusDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .actualFocusDuration) ?? 0
        pausedDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .pausedDuration) ?? 0
        warmupDuration = try values.decodeIfPresent(TimeInterval.self, forKey: .warmupDuration) ?? 0
        timerActivityRaw = try values.decodeIfPresent(String.self, forKey: .timerActivityRaw)
            ?? TimerActivity.pomodoro.rawValue
        modeRaw = try values.decodeIfPresent(String.self, forKey: .modeRaw) ?? FocusMode.standard.rawValue
        statusRaw = try values.decodeIfPresent(String.self, forKey: .statusRaw) ?? SessionStatus.completed.rawValue
        completionStateRaw = try values.decodeIfPresent(String.self, forKey: .completionStateRaw)
        energyBefore = try values.decodeIfPresent(Int.self, forKey: .energyBefore)
        energyAfter = try values.decodeIfPresent(Int.self, forKey: .energyAfter)
        note = try values.decodeIfPresent(String.self, forKey: .note) ?? ""
        distractionSourceRaw = try values.decodeIfPresent(String.self, forKey: .distractionSourceRaw)
    }
}

struct Interruption: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionID: UUID
    var startedAt: Date
    var endedAt: Date?
    var reasonRaw: String?
    var returnedToSameTask: Bool

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        reason: InterruptionReason? = nil,
        returnedToSameTask: Bool = true
    ) {
        self.id = id
        self.sessionID = sessionID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.reasonRaw = reason?.rawValue
        self.returnedToSameTask = returnedToSameTask
    }
}

struct Reflection: Identifiable, Codable, Hashable {
    var id: UUID
    var sessionID: UUID
    var blockerTypeRaw: String
    var freeText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        blockerType: BlockerType,
        freeText: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.sessionID = sessionID
        self.blockerTypeRaw = blockerType.rawValue
        self.freeText = freeText
        self.createdAt = createdAt
    }
}

struct DailySnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var totalFocusDuration: TimeInterval
    var sessionsCompleted: Int
    var startFriction: TimeInterval
    var interruptionRate: Double
    var planAccuracy: Double
    var topCategory: String
    var generatedSummary: String
}

struct MossDatabase: Codable {
    var projects: [FocusProject]
    var tasks: [FocusTask]
    var sessions: [FocusSession]
    var interruptions: [Interruption]
    var reflections: [Reflection]
    var snapshots: [DailySnapshot]

    init(
        projects: [FocusProject] = [],
        tasks: [FocusTask] = [],
        sessions: [FocusSession] = [],
        interruptions: [Interruption] = [],
        reflections: [Reflection] = [],
        snapshots: [DailySnapshot] = []
    ) {
        self.projects = projects
        self.tasks = tasks
        self.sessions = sessions
        self.interruptions = interruptions
        self.reflections = reflections
        self.snapshots = snapshots
    }

    private enum CodingKeys: String, CodingKey {
        case projects, tasks, sessions, interruptions, reflections, snapshots
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        projects = try values.decodeIfPresent([FocusProject].self, forKey: .projects) ?? []
        tasks = try values.decodeIfPresent([FocusTask].self, forKey: .tasks) ?? []
        sessions = try values.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        interruptions = try values.decodeIfPresent([Interruption].self, forKey: .interruptions) ?? []
        reflections = try values.decodeIfPresent([Reflection].self, forKey: .reflections) ?? []
        snapshots = try values.decodeIfPresent([DailySnapshot].self, forKey: .snapshots) ?? []
    }
}
