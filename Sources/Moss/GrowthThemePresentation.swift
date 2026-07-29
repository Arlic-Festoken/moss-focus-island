import Foundation

struct AchievementPresentation {
    let title: String
    let subtitle: String
    let symbol: String
}

extension GrowthTheme {
    func achievementPresentation(for achievement: Achievement) -> AchievementPresentation {
        guard self == .douluo else {
            return AchievementPresentation(
                title: achievement.title,
                subtitle: achievement.subtitle,
                symbol: achievement.symbol
            )
        }

        let themed: (title: String, subtitle: String, symbol: String)
        switch achievement.id {
        case "first":
            themed = ("初次冥想", "完成第一次有效修炼", "sparkles")
        case "25h":
            themed = ("魂力初醒", "累计修炼 25 小时", "bolt.circle.fill")
        case "100h":
            themed = ("百时魂印", "累计修炼 100 小时", "seal.fill")
        case "150h":
            themed = ("魂力凝聚", "累计修炼 150 小时", "circle.hexagongrid.fill")
        case "200h":
            themed = ("二百时突破", "累计修炼 200 小时", "arrow.up.forward.circle.fill")
        case "100sessions":
            themed = ("百次冥想", "完成 100 次有效修炼", "flag.checkered")
        case "300sessions":
            themed = ("三百次冥想", "完成 300 次有效修炼", "medal.star.fill")
        case "7days":
            themed = ("七日连修", "连续修炼 7 天", "flame.fill")
        case "expedition":
            themed = ("一日闭关", "单日有效修炼达到 7 小时", "moon.stars.fill")
        case "explorer":
            themed = ("灵识漫游", "探索型修炼达到 25 小时", "eye.circle.fill")
        case "landmark":
            themed = ("首枚千年魂环", "一个学习领域达到 25 小时", "circle.circle.fill")
        default:
            themed = (
                achievement.title,
                achievement.subtitle.replacingOccurrences(of: "专注", with: "修炼"),
                achievement.symbol
            )
        }
        return AchievementPresentation(
            title: themed.title,
            subtitle: themed.subtitle,
            symbol: themed.symbol
        )
    }

    var journalTitle: String {
        self == .douluo ? "修炼志" : "成长志"
    }

    var journalSubtitle: String {
        self == .douluo
            ? "不是更多统计，而是每一次修炼正在塑造怎样的魂师。"
            : "不是更多统计，而是你投入过的时间正在形成什么。"
    }

    var evidenceTitle: String {
        self == .douluo ? "修炼功勋" : "成长证据"
    }

    var evidenceSubtitle: String {
        self == .douluo
            ? "每一项功勋都有解锁日期，也有真实修炼记录作为依据。"
            : "每一个里程碑都有日期，也有真实投入作为依据。"
    }

    var nextMilestonePrefix: String {
        self == .douluo ? "下一功勋" : "下一里程碑"
    }
}
