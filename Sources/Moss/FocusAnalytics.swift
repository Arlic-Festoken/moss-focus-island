import Foundation
import SwiftUI

enum TitleGroup: String, CaseIterable, Identifiable, Codable {
    case academic
    case exploration
    case creative
    case wellbeing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .academic: "学业主线"
        case .exploration: "探索阅读"
        case .creative: "创造实践"
        case .wellbeing: "生活恢复"
        }
    }

    var subtitle: String {
        switch self {
        case .academic: "把难题变成陆地"
        case .exploration: "沿好奇心继续远航"
        case .creative: "让想法留下作品"
        case .wellbeing: "为长期投入补充能量"
        }
    }

    var symbol: String {
        switch self {
        case .academic: "graduationcap.fill"
        case .exploration: "safari.fill"
        case .creative: "hammer.fill"
        case .wellbeing: "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .academic: Color(red: 0.29, green: 0.56, blue: 0.82)
        case .exploration: Color(red: 0.55, green: 0.43, blue: 0.78)
        case .creative: Color(red: 0.88, green: 0.57, blue: 0.25)
        case .wellbeing: Color(red: 0.39, green: 0.69, blue: 0.55)
        }
    }
}

enum TitleMastery: String, CaseIterable, Identifiable {
    case seed
    case sprout
    case grove
    case landmark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seed: "种子"
        case .sprout: "萌芽"
        case .grove: "林地"
        case .landmark: "地标"
        }
    }

    var symbol: String {
        switch self {
        case .seed: "circle.dotted"
        case .sprout: "leaf.fill"
        case .grove: "tree.fill"
        case .landmark: "mountain.2.fill"
        }
    }

    static func resolve(duration: TimeInterval) -> TitleMastery {
        switch duration {
        case ..<(2 * 3_600): .seed
        case ..<(10 * 3_600): .sprout
        case ..<(25 * 3_600): .grove
        default: .landmark
        }
    }
}

struct TitleProfile: Identifiable {
    let title: String
    let group: TitleGroup
    let symbol: String
    let narrative: String

    var id: String { title }

    static func resolve(_ title: String) -> TitleProfile {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = clean.lowercased()
        if let profile = catalog[normalized] { return profile }

        let group: TitleGroup
        if normalized.contains("开发") || normalized.contains("coding") {
            group = .creative
        } else if normalized.contains("书") || normalized.contains("阅读") || normalized.contains("听力") {
            group = .exploration
        } else if normalized.contains("健身") || normalized.contains("游戏") {
            group = .wellbeing
        } else {
            group = .academic
        }
        return TitleProfile(title: clean, group: group, symbol: group.symbol, narrative: group.subtitle)
    }

    private static let catalog: [String: TitleProfile] = {
        func item(_ title: String, _ group: TitleGroup, _ symbol: String, _ narrative: String) -> (String, TitleProfile) {
            (title.lowercased(), TitleProfile(title: title, group: group, symbol: symbol, narrative: narrative))
        }
        return Dictionary(uniqueKeysWithValues: [
            item("课业", .academic, "books.vertical.fill", "一页一页，把课程推进成大陆。"),
            item("专业", .academic, "graduationcap.fill", "专业积累正在成为岛屿的根基。"),
            item("计组", .academic, "cpu.fill", "从位与指令开始搭建计算世界。"),
            item("最优化 算法", .academic, "point.3.connected.trianglepath.dotted", "沿更优路径逼近答案。"),
            item("高数", .academic, "function", "把抽象变化刻进地形。"),
            item("深度学习", .academic, "brain.head.profile", "训练理解，也训练耐心。"),
            item("算法题", .academic, "curlybraces.square.fill", "每次拆解都让路径更清晰。"),
            item("大物", .academic, "atom", "从规律里看见世界的骨架。"),
            item("离散数学", .academic, "square.grid.3x3.fill", "用结构连接分散的知识。"),
            item("概率论", .academic, "die.face.5.fill", "在不确定中建立判断。"),
            item("论文", .academic, "doc.text.fill", "把思考沉淀为可以传递的文字。"),
            item("录题", .academic, "square.and.pencil", "整理题目，也整理思路。"),
            item("学习", .academic, "lightbulb.fill", "一段朴素却真实的成长。"),
            item("漫游", .exploration, "safari.fill", "不设边界的探索，也会抵达新大陆。"),
            item("📖", .exploration, "book.fill", "阅读让岛屿拥有更远的视野。"),
            item("words", .exploration, "character.book.closed.fill", "词汇是通往另一种表达的桥。"),
            item("书", .exploration, "books.vertical.fill", "安静翻页，也是在向前。"),
            item("阅读训练", .exploration, "text.magnifyingglass", "让理解变得更快、更深。"),
            item("听力", .exploration, "ear.fill", "在声音里拓展新的航线。"),
            item("开发", .creative, "hammer.fill", "把想法变成可以运行的东西。"),
            item("vibe coding", .creative, "sparkles", "顺着灵感快速抵达作品。"),
            item("健身", .wellbeing, "figure.strengthtraining.traditional", "体力是长期专注的补给。"),
            item("游戏", .wellbeing, "gamecontroller.fill", "有意识地恢复，也属于完整生活。"),
            item("专注", .wellbeing, "scope", "为注意力本身留下一段空间。"),
            item("其他", .wellbeing, "ellipsis.circle.fill", "未命名的投入同样值得被看见。")
        ])
    }()
}

struct TitleMetric: Identifiable {
    let profile: TitleProfile
    let sessions: [FocusSession]
    let totalDuration: TimeInterval
    let completedCount: Int
    let firstDate: Date?
    let lastDate: Date?

    var id: String { profile.title }
    var title: String { profile.title }
    var mastery: TitleMastery { .resolve(duration: totalDuration) }
    var completedSessions: [FocusSession] { sessions.filter { $0.status == .completed } }
}

struct FocusDayRecord {
    let date: Date
    let duration: TimeInterval
    let sessionCount: Int
}

struct FocusMonthRecord {
    let date: Date
    let duration: TimeInterval
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let unlockedAt: Date?
    let progress: Double

    var isUnlocked: Bool { unlockedAt != nil }
}

enum HistoryStatusFilter: String, CaseIterable, Identifiable {
    case all
    case completed
    case abandoned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部状态"
        case .completed: "已完成"
        case .abandoned: "中途放弃"
        }
    }
}

struct HistoryFilter {
    var query = ""
    var group: TitleGroup?
    var title: String?
    var status: HistoryStatusFilter = .all

    func matches(_ session: FocusSession) -> Bool {
        if let group, TitleProfile.resolve(session.taskTitle).group != group { return false }
        if let title, session.taskTitle != title { return false }
        switch status {
        case .all: break
        case .completed where session.status != .completed: return false
        case .abandoned where session.status != .abandoned: return false
        default: break
        }
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return true }
        return [session.taskTitle, session.projectTitle, session.note]
            .contains { $0.localizedCaseInsensitiveContains(cleanQuery) }
    }
}

struct FocusAnalyticsSnapshot {
    let totalFocus: TimeInterval
    let currentYearFocus: TimeInterval
    let currentYearActiveDays: Int
    let recentFocus: TimeInterval
    let recentMonths: [FocusMonthRecord]
    let completionCount: Int
    let abandonedCount: Int
    let completionRate: Double
    let activeDays: Int
    let currentStreak: Int
    let longestStreak: Int
    let medianSession: TimeInterval
    let peakDay: FocusDayRecord?
    let peakMonth: FocusMonthRecord?
    let longestSession: FocusSession?
    let titleMetrics: [TitleMetric]
    let cultivation: FocusCultivationRank
    let experience: Int
    let level: Int
    let levelProgress: Double
    let experienceToNextLevel: Int
    let achievements: [Achievement]
    let latestUnlockedAchievement: Achievement?
    let nextAchievement: Achievement?

    init(sessions: [FocusSession], now: Date = .now, calendar: Calendar = .current) {
        let all = sessions.sorted { $0.startedAt < $1.startedAt }
        let completed = all.filter { $0.status == .completed }
        let total = completed.reduce(0) { $0 + $1.actualFocusDuration }
        let dailyGroups = Dictionary(grouping: completed) { calendar.startOfDay(for: $0.startedAt) }
        let dailyRecords = dailyGroups.map { date, items in
            FocusDayRecord(
                date: date,
                duration: items.reduce(0) { $0 + $1.actualFocusDuration },
                sessionCount: items.count
            )
        }
        let monthGroups = Dictionary(grouping: completed) { session -> Date in
            let components = calendar.dateComponents([.year, .month], from: session.startedAt)
            return calendar.date(from: components) ?? calendar.startOfDay(for: session.startedAt)
        }
        let monthRecords = monthGroups.map { date, items in
            FocusMonthRecord(date: date, duration: items.reduce(0) { $0 + $1.actualFocusDuration })
        }
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let recentStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let yearInterval = calendar.dateInterval(of: .year, for: now)
        let currentYearSessions = completed.filter { session in
            guard let yearInterval else { return false }
            return yearInterval.contains(session.startedAt)
        }
        let currentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? today
        let recentMonths = (0..<12).compactMap { index -> FocusMonthRecord? in
            guard let month = calendar.date(
                byAdding: .month,
                value: index - 11,
                to: currentMonth
            ) else {
                return nil
            }
            return FocusMonthRecord(
                date: month,
                duration: monthGroups[month]?.reduce(0) { $0 + $1.actualFocusDuration } ?? 0
            )
        }
        let sortedDates = dailyGroups.keys.sorted()
        let streaks = Self.streaks(dates: sortedDates, now: now, calendar: calendar)
        let durations = completed.map(\.actualFocusDuration).sorted()
        let median = durations.isEmpty ? 0 : durations[durations.count / 2]

        let groupedTitles = Dictionary(grouping: all, by: { $0.taskTitle })
        let titleMetrics = groupedTitles.map { title, items in
            let titleCompleted = items.filter { $0.status == .completed }
            return TitleMetric(
                profile: TitleProfile.resolve(title),
                sessions: items.sorted { $0.startedAt > $1.startedAt },
                totalDuration: titleCompleted.reduce(0) { $0 + $1.actualFocusDuration },
                completedCount: titleCompleted.count,
                firstDate: items.map(\.startedAt).min(),
                lastDate: items.map(\.startedAt).max()
            )
        }.sorted {
            if $0.totalDuration == $1.totalDuration { return $0.title < $1.title }
            return $0.totalDuration > $1.totalDuration
        }

        let xp = Int(total / 60)
        let cultivation = FocusCultivationRank(totalDuration: total)
        self.totalFocus = total
        currentYearFocus = currentYearSessions.reduce(0) { $0 + $1.actualFocusDuration }
        currentYearActiveDays = Set(
            currentYearSessions.map { calendar.startOfDay(for: $0.startedAt) }
        ).count
        recentFocus = completed
            .filter { $0.startedAt >= recentStart && $0.startedAt < tomorrow }
            .reduce(0) { $0 + $1.actualFocusDuration }
        self.recentMonths = recentMonths
        completionCount = completed.count
        abandonedCount = all.filter { $0.status == .abandoned }.count
        completionRate = all.isEmpty ? 0 : Double(completed.count) / Double(all.count)
        activeDays = dailyGroups.count
        currentStreak = streaks.current
        longestStreak = streaks.longest
        medianSession = median
        peakDay = dailyRecords.max { $0.duration < $1.duration }
        peakMonth = monthRecords.max { $0.duration < $1.duration }
        longestSession = completed.max { $0.actualFocusDuration < $1.actualFocusDuration }
        self.titleMetrics = titleMetrics
        self.cultivation = cultivation
        experience = xp
        level = cultivation.level
        levelProgress = cultivation.levelProgress
        experienceToNextLevel = Int(ceil(cultivation.durationToNextLevel / 60))
        let builtAchievements = Self.buildAchievements(
            completed: completed,
            dailyRecords: dailyRecords,
            titleMetrics: titleMetrics,
            total: total,
            longestStreak: streaks.longest,
            calendar: calendar
        )
        achievements = builtAchievements
        latestUnlockedAchievement = builtAchievements
            .filter(\.isUnlocked)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
            .first
        nextAchievement = builtAchievements.first { !$0.isUnlocked }
    }

    func metric(for title: String) -> TitleMetric? {
        titleMetrics.first { $0.title == title }
    }

    private static func streaks(dates: [Date], now: Date, calendar: Calendar) -> (current: Int, longest: Int) {
        guard !dates.isEmpty else { return (0, 0) }
        var longest = 0
        var running = 0
        var previous: Date?
        for date in dates {
            if let previous,
               calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                running += 1
            } else {
                running = 1
            }
            longest = max(longest, running)
            previous = date
        }

        let today = calendar.startOfDay(for: now)
        let last = dates.last ?? today
        let gap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        guard gap <= 1 else { return (0, longest) }
        let dateSet = Set(dates)
        var cursor = last
        var current = 0
        while dateSet.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return (current, longest)
    }

    private static func buildAchievements(
        completed: [FocusSession],
        dailyRecords: [FocusDayRecord],
        titleMetrics: [TitleMetric],
        total: TimeInterval,
        longestStreak: Int,
        calendar: Calendar
    ) -> [Achievement] {
        let chronological = completed.sorted { $0.startedAt < $1.startedAt }
        func crossingDate(seconds: TimeInterval) -> Date? {
            var running: TimeInterval = 0
            for session in chronological {
                running += session.actualFocusDuration
                if running >= seconds { return session.startedAt }
            }
            return nil
        }
        func countDate(_ count: Int) -> Date? {
            chronological.count >= count ? chronological[count - 1].startedAt : nil
        }
        func focusProgress(_ target: TimeInterval) -> Double { min(1, total / target) }
        let explorer = titleMetrics.first { $0.title == "漫游" }
        let firstLandmark = titleMetrics
            .filter { $0.totalDuration >= 25 * 3_600 }
            .compactMap { metric in
                metric.completedSessions.sorted { $0.startedAt < $1.startedAt }.reduce(into: (sum: TimeInterval(0), date: Date?.none)) { state, session in
                    guard state.date == nil else { return }
                    state.sum += session.actualFocusDuration
                    if state.sum >= 25 * 3_600 { state.date = session.startedAt }
                }.date
            }
            .min()
        let sevenHourDay = dailyRecords
            .filter { $0.duration >= 7 * 3_600 }
            .map(\.date)
            .min()
        let sevenDayDate = streakUnlockDate(completed: chronological, target: 7, calendar: calendar)

        return [
            Achievement(id: "first", title: "第一块苔藓", subtitle: "完成第一段专注", symbol: "leaf.fill", unlockedAt: countDate(1), progress: min(1, Double(completed.count))),
            Achievement(id: "25h", title: "岛屿初成", subtitle: "累计专注 25 小时", symbol: "map.fill", unlockedAt: crossingDate(seconds: 25 * 3_600), progress: focusProgress(25 * 3_600)),
            Achievement(id: "100h", title: "百小时航标", subtitle: "累计专注 100 小时", symbol: "flag.fill", unlockedAt: crossingDate(seconds: 100 * 3_600), progress: focusProgress(100 * 3_600)),
            Achievement(id: "150h", title: "深耕者", subtitle: "累计专注 150 小时", symbol: "tree.fill", unlockedAt: crossingDate(seconds: 150 * 3_600), progress: focusProgress(150 * 3_600)),
            Achievement(id: "200h", title: "二百小时大陆", subtitle: "累计专注 200 小时", symbol: "mountain.2.fill", unlockedAt: crossingDate(seconds: 200 * 3_600), progress: focusProgress(200 * 3_600)),
            Achievement(id: "100sessions", title: "百次归航", subtitle: "完成 100 段专注", symbol: "flag.checkered", unlockedAt: countDate(100), progress: min(1, Double(completed.count) / 100)),
            Achievement(id: "300sessions", title: "三百次归航", subtitle: "完成 300 段专注", symbol: "medal.star.fill", unlockedAt: countDate(300), progress: min(1, Double(completed.count) / 300)),
            Achievement(id: "7days", title: "七日潮汐", subtitle: "连续专注 7 天", symbol: "flame.fill", unlockedAt: sevenDayDate, progress: min(1, Double(longestStreak) / 7)),
            Achievement(id: "expedition", title: "一日远征", subtitle: "单日专注达到 7 小时", symbol: "figure.hiking", unlockedAt: sevenHourDay, progress: min(1, (dailyRecords.map(\.duration).max() ?? 0) / (7 * 3_600))),
            Achievement(id: "explorer", title: "漫游者", subtitle: "探索型学习达到 25 小时", symbol: "safari.fill", unlockedAt: explorer.flatMap { metric in
                var running: TimeInterval = 0
                for session in metric.completedSessions.sorted(by: { $0.startedAt < $1.startedAt }) {
                    running += session.actualFocusDuration
                    if running >= 25 * 3_600 { return session.startedAt }
                }
                return nil
            }, progress: min(1, (explorer?.totalDuration ?? 0) / (25 * 3_600))),
            Achievement(id: "landmark", title: "第一座地标", subtitle: "一个 title 达到 25 小时", symbol: "mappin.and.ellipse", unlockedAt: firstLandmark, progress: min(1, (titleMetrics.map(\.totalDuration).max() ?? 0) / (25 * 3_600)))
        ]
    }

    private static func streakUnlockDate(completed: [FocusSession], target: Int, calendar: Calendar) -> Date? {
        let dates = Array(Set(completed.map { calendar.startOfDay(for: $0.startedAt) })).sorted()
        var running = 0
        var previous: Date?
        for date in dates {
            if let previous,
               calendar.dateComponents([.day], from: previous, to: date).day == 1 {
                running += 1
            } else {
                running = 1
            }
            if running >= target { return date }
            previous = date
        }
        return nil
    }
}

struct FocusCompletionReceipt: Identifiable {
    let id: UUID
    let focusedDuration: TimeInterval
    let taskTitle: String
    let taskTotal: TimeInterval
    let overallTotal: TimeInterval
    let completionCount: Int
    let unlockedAchievement: Achievement?
    let nextAchievement: Achievement?

    static func make(
        focusedDuration: TimeInterval,
        taskTitle: String,
        before: FocusAnalyticsSnapshot,
        after: FocusAnalyticsSnapshot
    ) -> FocusCompletionReceipt {
        let previouslyUnlocked = Set(
            before.achievements.filter(\.isUnlocked).map(\.id)
        )
        let newlyUnlocked = after.achievements
            .filter { $0.isUnlocked && !previouslyUnlocked.contains($0.id) }
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
            .first

        return FocusCompletionReceipt(
            id: UUID(),
            focusedDuration: focusedDuration,
            taskTitle: taskTitle,
            taskTotal: after.metric(for: taskTitle)?.totalDuration ?? focusedDuration,
            overallTotal: after.totalFocus,
            completionCount: after.completionCount,
            unlockedAchievement: newlyUnlocked,
            nextAchievement: after.nextAchievement
        )
    }
}
