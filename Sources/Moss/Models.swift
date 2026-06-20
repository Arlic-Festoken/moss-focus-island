import Foundation

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

struct FocusTask: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var category: String
    var estimatedSessions: Int
    var completedSessions: Int
    var archived: Bool
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        estimatedSessions: Int = 1,
        completedSessions: Int = 0,
        archived: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.estimatedSessions = estimatedSessions
        self.completedSessions = completedSessions
        self.archived = archived
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

struct FocusSession: Identifiable, Codable, Hashable {
    var id: UUID
    var taskID: UUID
    var taskTitle: String
    var category: String
    var startedAt: Date
    var endedAt: Date?
    var plannedDuration: TimeInterval
    var actualFocusDuration: TimeInterval
    var pausedDuration: TimeInterval
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
        category: String,
        startedAt: Date = .now,
        plannedDuration: TimeInterval,
        mode: FocusMode
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.category = category
        self.startedAt = startedAt
        self.endedAt = nil
        self.plannedDuration = plannedDuration
        self.actualFocusDuration = 0
        self.pausedDuration = 0
        self.modeRaw = mode.rawValue
        self.statusRaw = SessionStatus.active.rawValue
        self.completionStateRaw = nil
        self.energyBefore = nil
        self.energyAfter = nil
        self.note = ""
        self.distractionSourceRaw = nil
    }

    var mode: FocusMode {
        FocusMode(rawValue: modeRaw) ?? .standard
    }

    var status: SessionStatus {
        SessionStatus(rawValue: statusRaw) ?? .completed
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
    var tasks: [FocusTask] = []
    var sessions: [FocusSession] = []
    var interruptions: [Interruption] = []
    var reflections: [Reflection] = []
    var snapshots: [DailySnapshot] = []
}
