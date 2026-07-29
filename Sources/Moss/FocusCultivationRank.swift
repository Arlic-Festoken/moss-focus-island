import Foundation

enum GrowthTheme: String, CaseIterable, Identifiable {
    case moss
    case douluo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moss: "专注岛"
        case .douluo: "斗罗大陆"
        }
    }

    var subtitle: String {
        switch self {
        case .moss: "以种子、林地和地标记录长期积累"
        case .douluo: "以魂力等级、境界与魂环记录万时成长"
        }
    }

    var symbol: String {
        switch self {
        case .moss: "leaf.fill"
        case .douluo: "circle.hexagongrid.fill"
        }
    }
}

struct FocusCultivationRank: Equatable {
    static let maximumLevel = 99
    static let masteryHours = 10_000.0
    static let soulRingYearsPerHour = 100.0

    let totalDuration: TimeInterval

    var totalHours: Double {
        max(0, totalDuration / 3_600)
    }

    var level: Int {
        (1...Self.maximumLevel).last {
            totalHours + 0.000_001 >= Self.hoursRequired(for: $0)
        } ?? 1
    }

    var realm: FocusRealm {
        .resolve(level: level)
    }

    var nextRealm: FocusRealm? {
        FocusRealm.allCases.first { $0.lowerBound > level }
    }

    var hoursRequiredForCurrentLevel: Double {
        Self.hoursRequired(for: level)
    }

    var hoursRequiredForNextLevel: Double? {
        guard level < Self.maximumLevel else { return nil }
        return Self.hoursRequired(for: level + 1)
    }

    var levelProgress: Double {
        guard let nextHours = hoursRequiredForNextLevel else { return 1 }
        let currentHours = hoursRequiredForCurrentLevel
        let span = max(0.000_1, nextHours - currentHours)
        return min(1, max(0, (totalHours - currentHours) / span))
    }

    var durationToNextLevel: TimeInterval {
        guard let nextHours = hoursRequiredForNextLevel else { return 0 }
        return max(0, nextHours - totalHours) * 3_600
    }

    var hoursRequiredForNextRealm: Double? {
        nextRealm.map { Self.hoursRequired(for: $0.lowerBound) }
    }

    var durationToNextRealm: TimeInterval {
        guard let hoursRequiredForNextRealm else { return 0 }
        return max(0, hoursRequiredForNextRealm - totalHours) * 3_600
    }

    var soulRingYears: Int {
        min(
            1_000_000,
            max(0, Int(floor(totalHours * Self.soulRingYearsPerHour)))
        )
    }

    var soulRingTier: SoulRingTier {
        .resolve(years: soulRingYears)
    }

    var formattedSoulRingYears: String {
        "\(soulRingYears.formatted()) 年"
    }

    static func hoursRequired(for level: Int) -> Double {
        let clampedLevel = min(maximumLevel, max(1, level))
        let normalized = Double(clampedLevel - 1) / 98.0
        return masteryHours * pow(normalized, 3)
    }
}

enum FocusRealm: String, CaseIterable, Identifiable {
    case soulScholar
    case soulMaster
    case grandSoulMaster
    case soulElder
    case soulAncestor
    case soulKing
    case soulEmperor
    case soulSage
    case soulDouluo
    case titledDouluo
    case superDouluo
    case limitDouluo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soulScholar: "魂士"
        case .soulMaster: "魂师"
        case .grandSoulMaster: "大魂师"
        case .soulElder: "魂尊"
        case .soulAncestor: "魂宗"
        case .soulKing: "魂王"
        case .soulEmperor: "魂帝"
        case .soulSage: "魂圣"
        case .soulDouluo: "魂斗罗"
        case .titledDouluo: "封号斗罗"
        case .superDouluo: "超级斗罗"
        case .limitDouluo: "极限斗罗"
        }
    }

    var lowerBound: Int {
        switch self {
        case .soulScholar: 1
        case .soulMaster: 10
        case .grandSoulMaster: 20
        case .soulElder: 30
        case .soulAncestor: 40
        case .soulKing: 50
        case .soulEmperor: 60
        case .soulSage: 70
        case .soulDouluo: 80
        case .titledDouluo: 90
        case .superDouluo: 95
        case .limitDouluo: 99
        }
    }

    var upperBound: Int {
        switch self {
        case .soulScholar: 9
        case .soulMaster: 19
        case .grandSoulMaster: 29
        case .soulElder: 39
        case .soulAncestor: 49
        case .soulKing: 59
        case .soulEmperor: 69
        case .soulSage: 79
        case .soulDouluo: 89
        case .titledDouluo: 94
        case .superDouluo: 98
        case .limitDouluo: 99
        }
    }

    var levelRange: String {
        lowerBound == upperBound
            ? "\(lowerBound) 级"
            : "\(lowerBound)–\(upperBound) 级"
    }

    static func resolve(level: Int) -> FocusRealm {
        allCases.last { level >= $0.lowerBound } ?? .soulScholar
    }
}

enum SoulRingTier: String, CaseIterable, Identifiable {
    case nascent
    case tenYear
    case hundredYear
    case thousandYear
    case tenThousandYear
    case hundredThousandYear
    case millionYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nascent: "初生魂环"
        case .tenYear: "十年魂环"
        case .hundredYear: "百年魂环"
        case .thousandYear: "千年魂环"
        case .tenThousandYear: "万年魂环"
        case .hundredThousandYear: "十万年魂环"
        case .millionYear: "百万年魂环"
        }
    }

    static func resolve(years: Int) -> SoulRingTier {
        switch years {
        case ..<10: .nascent
        case ..<100: .tenYear
        case ..<1_000: .hundredYear
        case ..<10_000: .thousandYear
        case ..<100_000: .tenThousandYear
        case ..<1_000_000: .hundredThousandYear
        default: .millionYear
        }
    }
}
