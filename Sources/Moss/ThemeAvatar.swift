import Foundation

enum DouluoAvatarForm: String, CaseIterable, Identifiable {
    case soulMaster
    case soulBeast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soulMaster: "魂师"
        case .soulBeast: "魂兽"
        }
    }

    var symbol: String {
        switch self {
        case .soulMaster: "figure.mind.and.body"
        case .soulBeast: "pawprint.fill"
        }
    }
}

struct ThemeSoulRing: Identifiable {
    let id: UUID
    let title: String
    let duration: TimeInterval
    let isArchived: Bool
    let archivedAt: Date?

    var rank: FocusCultivationRank { FocusCultivationRank(totalDuration: duration) }
}

struct ThemeSoulSpirit: Identifiable {
    let id: UUID
    let title: String
    let symbol: String
    let duration: TimeInterval
    let taskCount: Int
    let isArchived: Bool
    let archivedAt: Date?
}

struct ThemeMartialSoul: Identifiable {
    let group: TitleGroup
    let duration: TimeInterval

    var id: String { group.rawValue }
}

enum ThemeTrainingRoute: String, Identifiable, Hashable {
    case mecha
    case soulSpirit
    case synergy

    var id: String { rawValue }
}

struct ThemeTrainingRecommendation: Identifiable {
    let route: ThemeTrainingRoute
    let title: String
    let taskID: UUID
    let taskTitle: String
    let projectTitle: String
    let reason: String
    let expectedPowerGain: Int

    var id: String { route.rawValue }
}

enum ThemeOrganizationKind: String, CaseIterable, Identifiable {
    case academy
    case spiritPagoda
    case warGodHall
    case empire
    case continent

    var id: String { rawValue }
}

struct ThemeOrganizationNode: Identifiable {
    let kind: ThemeOrganizationKind
    let title: String
    let subtitle: String
    let symbol: String
    let progress: Double
    let powerBonus: Int

    var id: String { kind.rawValue }
    var isUnlocked: Bool { progress >= 1 }
}

struct ThemeAvatarSnapshot {
    let analytics: FocusAnalyticsSnapshot
    let projects: [FocusProject]
    let tasks: [FocusTask]
    let sessions: [FocusSession]

    init(
        analytics: FocusAnalyticsSnapshot,
        projects: [FocusProject] = [],
        tasks: [FocusTask] = [],
        sessions: [FocusSession] = []
    ) {
        self.analytics = analytics
        self.projects = projects
        self.tasks = tasks
        self.sessions = sessions
    }

    var rank: FocusCultivationRank {
        analytics.cultivation
    }

    var soulRings: [ThemeSoulRing] {
        (activeSoulRings + archivedSoulRings)
            .sorted { $0.duration > $1.duration }
    }

    var soulRingCapacity: Int {
        min(9, rank.level / 10)
    }

    var equippedSoulRings: [ThemeSoulRing] {
        Array(activeSoulRings.prefix(soulRingCapacity))
    }

    var unequippedSoulRingCandidates: [ThemeSoulRing] {
        Array(activeSoulRings.dropFirst(soulRingCapacity))
    }

    var activeSoulRings: [ThemeSoulRing] {
        ringRecords.filter { !$0.isArchived }
    }

    var archivedSoulRings: [ThemeSoulRing] {
        ringRecords.filter(\.isArchived)
    }

    var activeSoulSpirits: [ThemeSoulSpirit] {
        soulSpiritRecords.filter { !$0.isArchived }
    }

    var archivedSoulSpirits: [ThemeSoulSpirit] {
        soulSpiritRecords.filter(\.isArchived)
    }

    var martialSouls: [ThemeMartialSoul] {
        let activeMetrics: [TitleMetric]
        if tasks.isEmpty {
            activeMetrics = analytics.titleMetrics
        } else {
            let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
            let activeTitles = Set(
                tasks
                    .filter { task in
                        guard !task.archived else { return false }
                        return !(task.projectID.flatMap { projectsByID[$0] }?.archived ?? false)
                    }
                    .map(\.title)
            )
            activeMetrics = analytics.titleMetrics.filter { activeTitles.contains($0.title) }
        }

        let grouped = Dictionary(grouping: activeMetrics, by: \.profile.group)
            .map { group, metrics in
                ThemeMartialSoul(
                    group: group,
                    duration: metrics.reduce(0) { $0 + $1.totalDuration }
                )
            }
            .filter { $0.duration > 0 }
            .sorted { $0.duration > $1.duration }

        guard let primary = grouped.first else { return [] }
        guard grouped.count > 1 else { return [primary] }
        let secondary = grouped[1]
        let isTwinSoul = secondary.duration >= 10 * 3_600
            && secondary.duration >= primary.duration * 0.35
        return isTwinSoul ? [primary, secondary] : [primary]
    }

    var soulBoneSlots: [String] {
        let slots = ["头部", "躯干", "左臂", "右臂", "左腿", "右腿"]
        let unlockedAchievements = analytics.achievements.filter(\.isUnlocked).count
        let unlockedCount = min(slots.count, unlockedAchievements / 2)
        return Array(slots.prefix(unlockedCount))
    }

    var battleArmorTitle: String {
        switch analytics.longestStreak {
        case 90...: "四字斗铠"
        case 30...: "三字斗铠"
        case 14...: "二字斗铠"
        case 7...: "一字斗铠"
        default: "斗铠未觉醒"
        }
    }

    var mechaTitle: String {
        switch analytics.completionCount {
        case 1_000...: "红级机甲"
        case 500...: "黑级机甲"
        case 200...: "紫级机甲"
        case 50...: "黄级机甲"
        default: "基础机甲"
        }
    }

    var combatPower: Int {
        let hours = analytics.totalFocus / 3_600
        let unlockedAchievements = analytics.achievements.filter(\.isUnlocked).count
        return Int(hours * 120)
            + analytics.completionCount * 35
            + analytics.activeDays * 80
            + analytics.longestStreak * 500
            + unlockedAchievements * 1_000
            + analytics.titleMetrics.count * 300
            + synergyPower
            + organizationPower
    }

    var synergyPower: Int {
        let hours = groupHours
        func pair(_ first: TitleGroup, _ second: TitleGroup, coefficient: Double) -> Int {
            Int(min(hours[first, default: 0], hours[second, default: 0]) * coefficient)
        }
        return pair(.academic, .exploration, coefficient: 48)
            + pair(.academic, .creative, coefficient: 56)
            + pair(.academic, .wellbeing, coefficient: 34)
            + pair(.exploration, .creative, coefficient: 30)
    }

    var trainingRecommendations: [ThemeTrainingRecommendation] {
        var recommendations: [ThemeTrainingRecommendation] = []
        if let mecha = mechaRecommendation { recommendations.append(mecha) }
        if let soulSpirit = soulSpiritRecommendation { recommendations.append(soulSpirit) }
        if let synergy = synergyRecommendation { recommendations.append(synergy) }
        return recommendations
    }

    var organizationNodes: [ThemeOrganizationNode] {
        let totalHours = analytics.totalFocus / 3_600
        let spiritCount = activeSoulSpirits.count + archivedSoulSpirits.count
        let ringCount = activeSoulRings.count + archivedSoulRings.count
        let developedGroups = groupHours.values.filter { $0 >= 100 }.count

        let academyProgress = min(
            1,
            min(
                Double(activeSoulSpirits.count) / 2,
                totalHours / 25
            )
        )
        let pagodaProgress = min(
            1,
            min(Double(spiritCount) / 3, Double(ringCount) / 3)
        )
        let warGodProgress = min(
            1,
            min(
                Double(analytics.completionCount) / 300,
                Double(analytics.longestStreak) / 7
            )
        )
        let empireProgress = min(
            1,
            min(Double(rank.level) / 90, Double(developedGroups) / 3)
        )
        let continentProgress = min(1, totalHours / FocusCultivationRank.masteryHours)

        return [
            ThemeOrganizationNode(
                kind: .academy,
                title: "魂师学院",
                subtitle: "2 个活跃大项目，并累计修炼 25 小时",
                symbol: "graduationcap.fill",
                progress: academyProgress,
                powerBonus: 1_500
            ),
            ThemeOrganizationNode(
                kind: .spiritPagoda,
                title: "传灵塔",
                subtitle: "收录 3 个项目魂灵与 3 个任务魂环",
                symbol: "building.columns.fill",
                progress: pagodaProgress,
                powerBonus: 2_500
            ),
            ThemeOrganizationNode(
                kind: .warGodHall,
                title: "战神殿",
                subtitle: "完成 300 次修炼，并保持最长连续 7 天",
                symbol: "shield.checkered",
                progress: warGodProgress,
                powerBonus: 4_000
            ),
            ThemeOrganizationNode(
                kind: .empire,
                title: "修炼帝国",
                subtitle: "达到 90 级，且 3 个大领域分别超过 100 小时",
                symbol: "crown.fill",
                progress: empireProgress,
                powerBonus: 12_000
            ),
            ThemeOrganizationNode(
                kind: .continent,
                title: "万时大陆",
                subtitle: "累计完成 10,000 小时有效修炼",
                symbol: "globe.asia.australia.fill",
                progress: continentProgress,
                powerBonus: 30_000
            )
        ]
    }

    var organizationPower: Int {
        organizationNodes
            .filter(\.isUnlocked)
            .reduce(0) { $0 + $1.powerBonus }
    }

    var currentAffiliation: String {
        organizationNodes.last { $0.isUnlocked }?.title ?? "独立魂师"
    }

    var islandStage: String {
        switch analytics.totalFocus / 3_600 {
        case 1_000...: "专注大陆"
        case 500...: "繁茂群岛"
        case 100...: "成长之岛"
        case 25...: "初成小岛"
        case 1...: "苔藓岛礁"
        default: "待发芽的岛"
        }
    }

    private var ringRecords: [ThemeSoulRing] {
        guard !tasks.isEmpty || !sessions.isEmpty else {
            return analytics.titleMetrics
                .filter { $0.totalDuration > 0 }
                .map {
                    ThemeSoulRing(
                        id: UUID(),
                        title: $0.title,
                        duration: $0.totalDuration,
                        isArchived: false,
                        archivedAt: nil
                    )
                }
                .sorted { $0.duration > $1.duration }
        }

        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let completedSessions = sessions.filter { $0.status == .completed }
        let knownTaskIDs = Set(tasks.map(\.id))
        let taskRings = tasks.compactMap { task -> ThemeSoulRing? in
            let duration = completedSessions
                .filter { $0.taskID == task.id }
                .reduce(0) { $0 + $1.actualFocusDuration }
            guard duration > 0 else { return nil }
            let project = task.projectID.flatMap { projectsByID[$0] }
            return ThemeSoulRing(
                id: task.id,
                title: task.title,
                duration: duration,
                isArchived: task.archived || (project?.archived ?? false),
                archivedAt: task.archivedAt ?? project?.archivedAt
            )
        }
        let legacyRings = Dictionary(
            grouping: completedSessions.filter { !knownTaskIDs.contains($0.taskID) },
            by: \.taskID
        ).map { taskID, taskSessions in
            ThemeSoulRing(
                id: taskID,
                title: taskSessions.first?.taskTitle ?? "历史任务",
                duration: taskSessions.reduce(0) { $0 + $1.actualFocusDuration },
                isArchived: true,
                archivedAt: nil
            )
        }
        return (taskRings + legacyRings).sorted { $0.duration > $1.duration }
    }

    private var groupHours: [TitleGroup: Double] {
        Dictionary(grouping: analytics.titleMetrics, by: \.profile.group)
            .mapValues { metrics in
                metrics.reduce(0) { $0 + $1.totalDuration } / 3_600
            }
    }

    private var activeTasks: [FocusTask] {
        let projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        return tasks.filter { task in
            guard !task.archived else { return false }
            return !(task.projectID.flatMap { projectsByID[$0] }?.archived ?? false)
        }
    }

    private func taskDuration(_ task: FocusTask) -> TimeInterval {
        sessions
            .filter { $0.taskID == task.id && $0.status == .completed }
            .reduce(0) { $0 + $1.actualFocusDuration }
    }

    private func expectedPowerGain(for task: FocusTask) -> Int {
        let group = TitleProfile.resolve(task.title).group
        let hours = groupHours
        let dominant = hours.max { $0.value < $1.value }
        let base = max(1, Int(task.focusDuration / 3_600 * 120)) + 35
        var multiplier = 1.0
        if let dominant,
           group != dominant.key,
           hours[group, default: 0] < dominant.value * 0.60 {
            multiplier += 0.45
        } else if group != dominant?.key {
            multiplier += 0.20
        }
        if group == .creative { multiplier += 0.18 }
        if task.projectID != nil { multiplier += 0.10 }
        return Int((Double(base) * multiplier).rounded())
    }

    private var mechaRecommendation: ThemeTrainingRecommendation? {
        guard let task = activeTasks.max(by: { mechaScore($0) < mechaScore($1) }) else {
            return nil
        }
        let group = TitleProfile.resolve(task.title).group
        guard group == .creative || mechaScore(task) >= 70 else { return nil }
        return ThemeTrainingRecommendation(
            route: .mecha,
            title: "机甲实训",
            taskID: task.id,
            taskTitle: task.title,
            projectTitle: projectTitle(for: task),
            reason: "开发、算法或工程实践会直接积累机甲完成度，并计入领域协同。",
            expectedPowerGain: expectedPowerGain(for: task)
        )
    }

    private func mechaScore(_ task: FocusTask) -> Int {
        let title = task.title.lowercased()
        var score = TitleProfile.resolve(task.title).group == .creative ? 100 : 0
        for keyword in ["开发", "coding", "代码", "算法", "工程", "计组", "项目"] {
            if title.contains(keyword) { score += 35 }
        }
        return score
    }

    private var soulSpiritRecommendation: ThemeTrainingRecommendation? {
        guard let spirit = activeSoulSpirits
            .filter({ $0.taskCount > 0 })
            .min(by: { $0.duration < $1.duration }) else {
            return nil
        }
        let candidates = activeTasks.filter { $0.projectID == spirit.id }
        guard let task = candidates.min(by: { taskDuration($0) < taskDuration($1) }) else {
            return nil
        }
        return ThemeTrainingRecommendation(
            route: .soulSpirit,
            title: "强化「\(spirit.title)」魂灵",
            taskID: task.id,
            taskTitle: task.title,
            projectTitle: spirit.title,
            reason: "魂灵由大项目生成；完成其子任务会直接增加该魂灵的修炼时长。",
            expectedPowerGain: expectedPowerGain(for: task)
        )
    }

    private var synergyRecommendation: ThemeTrainingRecommendation? {
        guard let dominant = groupHours.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        let complements: [TitleGroup] = switch dominant {
        case .academic: [.exploration, .wellbeing, .creative]
        case .exploration: [.academic, .creative, .wellbeing]
        case .creative: [.academic, .wellbeing, .exploration]
        case .wellbeing: [.academic, .exploration, .creative]
        }
        guard let complement = complements.first(where: { target in
            activeTasks.contains { TitleProfile.resolve($0.title).group == target }
        }) else {
            return nil
        }
        let candidates = activeTasks.filter {
            TitleProfile.resolve($0.title).group == complement
        }
        guard let task = candidates.max(by: {
            expectedPowerGain(for: $0) < expectedPowerGain(for: $1)
        }) else {
            return nil
        }
        return ThemeTrainingRecommendation(
            route: .synergy,
            title: "\(dominant.title) × \(complement.title) 协同",
            taskID: task.id,
            taskTitle: task.title,
            projectTitle: projectTitle(for: task),
            reason: synergyReason(dominant: dominant, complement: complement),
            expectedPowerGain: expectedPowerGain(for: task)
        )
    }

    private func synergyReason(dominant: TitleGroup, complement: TitleGroup) -> String {
        if dominant == .academic && complement == .exploration {
            return "学业主线配合阅读探索，可同时增强理解深度与知识迁移，获得更高协同战力。"
        }
        if complement == .wellbeing {
            return "为高投入主线补充恢复训练，可以维持连续修炼并获得稳定性加成。"
        }
        if complement == .creative {
            return "把主线知识转化为作品或实践，可获得应用型协同加成。"
        }
        return "补足当前较弱的领域，比继续重复单一主线获得更高协同战力。"
    }

    private func projectTitle(for task: FocusTask) -> String {
        guard let projectID = task.projectID,
              let project = projects.first(where: { $0.id == projectID }) else {
            return task.category
        }
        return project.title
    }

    private var soulSpiritRecords: [ThemeSoulSpirit] {
        let completedSessions = sessions.filter { $0.status == .completed }
        return projects
            .map { project in
                ThemeSoulSpirit(
                    id: project.id,
                    title: project.title,
                    symbol: project.symbol,
                    duration: completedSessions
                        .filter { $0.projectID == project.id }
                        .reduce(0) { $0 + $1.actualFocusDuration },
                    taskCount: tasks.filter { $0.projectID == project.id }.count,
                    isArchived: project.archived,
                    archivedAt: project.archivedAt
                )
            }
            .filter { $0.taskCount > 0 || $0.duration > 0 }
            .sorted {
                if $0.isArchived != $1.isArchived { return !$0.isArchived }
                return $0.duration > $1.duration
            }
    }
}
