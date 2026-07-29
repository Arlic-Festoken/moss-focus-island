import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var dataStore: DataStore
    @AppStorage("growthTheme") private var growthThemeRaw = GrowthTheme.douluo.rawValue
    @AppStorage("douluoAvatarForm") private var douluoAvatarFormRaw = DouluoAvatarForm.soulMaster.rawValue
    @State private var selectedTitle: TitleMetric?

    private var analytics: FocusAnalyticsSnapshot {
        dataStore.analyticsSnapshot
    }

    private var growthTheme: GrowthTheme {
        GrowthTheme(rawValue: growthThemeRaw) ?? .douluo
    }

    private var douluoAvatarForm: DouluoAvatarForm {
        DouluoAvatarForm(rawValue: douluoAvatarFormRaw) ?? .soulMaster
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                pageHeader
                bodyOfWorkHero
                themedGrowthModule
                metricStrip

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        MonthlyChronicleCard(
                            months: analytics.recentMonths,
                            peakDay: analytics.peakDay,
                            peakMonth: analytics.peakMonth,
                            longestStreak: analytics.longestStreak
                        )
                        .frame(minWidth: 470, maxWidth: .infinity)
                        IslandMapCard(metrics: analytics.titleMetrics) { selectedTitle = $0 }
                            .frame(width: 410)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        MonthlyChronicleCard(
                            months: analytics.recentMonths,
                            peakDay: analytics.peakDay,
                            peakMonth: analytics.peakMonth,
                            longestStreak: analytics.longestStreak
                        )
                        IslandMapCard(metrics: analytics.titleMetrics) { selectedTitle = $0 }
                    }
                }

                growthEvidence

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        personalRecords.frame(maxWidth: .infinity)
                        titleLeaderboard.frame(width: 350)
                    }
                    VStack(spacing: 18) {
                        personalRecords
                        titleLeaderboard
                    }
                }

                FocusHeatmapView(sessions: dataStore.sessions)
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .sheet(item: $selectedTitle) { metric in
            TitleDetailView(metric: metric)
        }
    }

    private var pageHeader: some View {
        MossPageHeader(
            eyebrow: "Growth Journal",
            title: growthTheme.journalTitle,
            subtitle: growthTheme.journalSubtitle
        ) {
            if let latest = analytics.latestUnlockedAchievement {
                let presentation = growthTheme.achievementPresentation(for: latest)
                Label("最近解锁 · \(presentation.title)", systemImage: presentation.symbol)
                    .font(MossTypography.font(12, weight: .semibold))
                    .foregroundStyle(MossTheme.sage)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(MossTheme.sage.opacity(0.1), in: Capsule())
            }
        }
    }

    private var bodyOfWorkHero: some View {
        MossCard(kind: .hero) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 26) {
                    bodyOfWorkStatement
                    Spacer(minLength: 12)
                    YearSealCard(analytics: analytics, theme: growthTheme)
                        .frame(width: 330)
                }
                VStack(alignment: .leading, spacing: 20) {
                    bodyOfWorkStatement
                    YearSealCard(analytics: analytics, theme: growthTheme)
                }
            }
        }
    }

    private var bodyOfWorkStatement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                growthTheme == .douluo
                    ? "你的每一次修炼，都在凝聚新的魂力。"
                    : "你的投入，正在成为可以回望的作品。"
            )
                .font(MossTypography.editorial(29, weight: .semibold))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            if analytics.totalFocus > 0 {
                (
                    Text(growthTheme == .douluo ? "截至今天，你已经有效修炼 " : "截至今天，你已经为重要的事投入 ")
                        .foregroundStyle(.secondary)
                    + Text(analytics.totalFocus.chineseDuration)
                        .foregroundStyle(MossTheme.sage)
                        .fontWeight(.bold)
                    + Text("。")
                        .foregroundStyle(.secondary)
                )
                .font(MossTypography.font(14))
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(
                    growthTheme == .douluo
                        ? "完成第一次有效修炼后，这里会开始记录你的修炼轨迹。"
                        : "完成第一段专注后，这里会开始记录你的作品。"
                )
                    .font(MossTypography.font(14))
                    .foregroundStyle(.secondary)
            }
            if let first = analytics.titleMetrics
                .compactMap(\.firstDate)
                .min() {
                Label(
                    growthTheme == .douluo
                        ? "从 \(first.formatted(.dateTime.year().month().day())) 开始修炼"
                        : "从 \(first.formatted(.dateTime.year().month().day())) 开始生长",
                    systemImage: "calendar.badge.clock"
                )
                .font(MossTypography.font(11, weight: .semibold))
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 600, alignment: .leading)
    }

    private var metricStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { metricTiles }
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                metricTiles
            }
        }
    }

    private var cultivationRankCard: some View {
        FocusCultivationRankCard(rank: analytics.cultivation)
    }

    @ViewBuilder
    private var themedGrowthModule: some View {
        switch growthTheme {
        case .moss:
            ThemeAvatarProfileCard(
                snapshot: ThemeAvatarSnapshot(
                    analytics: analytics,
                    projects: dataStore.projects,
                    tasks: dataStore.tasks,
                    sessions: dataStore.sessions
                ),
                theme: .moss
            )
        case .douluo:
            ThemeAvatarProfileCard(
                snapshot: ThemeAvatarSnapshot(
                    analytics: analytics,
                    projects: dataStore.projects,
                    tasks: dataStore.tasks,
                    sessions: dataStore.sessions
                ),
                theme: .douluo
            )
            if douluoAvatarForm == .soulMaster {
                cultivationRankCard
            }
        }
    }

    @ViewBuilder private var metricTiles: some View {
        AchievementMetricTile(
            title: "完成段数",
            value: "\(analytics.completionCount)",
            icon: "checkmark.seal.fill",
            tint: MossTheme.mint
        )
        AchievementMetricTile(
            title: "留下痕迹",
            value: "\(analytics.activeDays) 天",
            icon: "calendar",
            tint: MossTheme.sage
        )
        AchievementMetricTile(
            title: "最长连续",
            value: "\(analytics.longestStreak) 天",
            icon: "flame.fill",
            tint: MossTheme.apricot
        )
        AchievementMetricTile(
            title: "持续领域",
            value: "\(analytics.titleMetrics.count)",
            icon: "map.fill",
            tint: TitleGroup.exploration.color
        )
    }

    private var growthEvidence: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(growthTheme.evidenceTitle)
                            .font(MossTypography.editorial(21, weight: .semibold))
                        Text(growthTheme.evidenceSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("已保存 \(unlockedEvidence.count) 项")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if unlockedEvidence.isEmpty {
                    ContentUnavailableView(
                        growthTheme == .douluo ? "功勋正在等待第一次修炼" : "证据正在等待第一段投入",
                        systemImage: growthTheme == .douluo ? "sparkles" : "leaf",
                        description: Text(
                            growthTheme == .douluo
                                ? "完成一次有效修炼后，第一项修炼功勋会在这里解锁。"
                                : "完成一段有效专注后，第一块苔藓会留在这里。"
                        )
                    )
                    .frame(minHeight: 150)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(unlockedEvidence) { achievement in
                            AchievementEvidenceCard(
                                achievement: achievement,
                                theme: growthTheme
                            )
                        }
                    }
                }

                if let next = analytics.nextAchievement {
                    NextMilestoneRow(achievement: next, theme: growthTheme)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var unlockedEvidence: [Achievement] {
        analytics.achievements
            .filter(\.isUnlocked)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
    }

    private var personalRecords: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("个人纪录")
                    .font(MossTypography.editorial(20, weight: .semibold))
                recordRow(
                    "最高单日",
                    analytics.peakDay?.duration.chineseDuration ?? "还没有",
                    analytics.peakDay?.date.formatted(.dateTime.year().month().day()) ?? "完成一段专注后出现",
                    "sun.max.fill"
                )
                Divider().opacity(0.5)
                recordRow(
                    "最佳月份",
                    analytics.peakMonth?.duration.chineseDuration ?? "还没有",
                    analytics.peakMonth?.date.formatted(.dateTime.year().month(.wide)) ?? "等待第一批记录",
                    "calendar"
                )
                Divider().opacity(0.5)
                recordRow(
                    "最长单次",
                    analytics.longestSession?.actualFocusDuration.chineseDuration ?? "还没有",
                    analytics.longestSession.map { "\($0.taskTitle) · \($0.startedAt.formatted(.dateTime.year().month().day()))" } ?? "等待第一批记录",
                    "flag.fill"
                )
            }
        }
    }

    private func recordRow(_ title: String, _ value: String, _ subtitle: String, _ icon: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(MossTheme.sage)
                .frame(width: 34, height: 34)
                .background(MossTheme.sage.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(subtitle).font(MossTypography.font(12, weight: .medium))
            }
            Spacer()
            Text(value)
                .font(MossTypography.font(17, weight: .bold))
                .monospacedDigit()
        }
    }

    private var titleLeaderboard: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("领域纵深")
                        .font(MossTypography.editorial(20, weight: .semibold))
                    Spacer()
                    Text("按有效时长")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if analytics.titleMetrics.isEmpty {
                    ContentUnavailableView("岛上还没有区域", systemImage: "map")
                        .frame(height: 180)
                } else {
                    ForEach(Array(analytics.titleMetrics.prefix(6).enumerated()), id: \.element.id) { index, metric in
                        Button { selectedTitle = metric } label: {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(MossTypography.font(11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                Image(systemName: metric.profile.symbol)
                                    .foregroundStyle(metric.profile.group.color)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(metric.title).font(MossTypography.font(13, weight: .semibold))
                                    Text("\(metric.mastery.title) · \(metric.completedCount) 段")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(metric.totalDuration.compactDuration)
                                    .font(MossTypography.font(12, weight: .bold))
                                    .foregroundStyle(metric.profile.group.color)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MossJellyPlainButtonStyle())
                        .mossJellyHover(scale: 1.018, lift: 1.5, glow: 0.08)
                    }
                }
            }
        }
    }
}

private struct ThemeAvatarProfileCard: View {
    @EnvironmentObject private var store: AppStore
    let snapshot: ThemeAvatarSnapshot
    let theme: GrowthTheme
    @AppStorage("douluoAvatarForm") private var avatarFormRaw = DouluoAvatarForm.soulMaster.rawValue
    @State private var isShowingArchivedGrowth = false
    @State private var isShowingRingCandidates = false
    @State private var isShowingOrganizations = false

    private var avatarForm: DouluoAvatarForm {
        DouluoAvatarForm(rawValue: avatarFormRaw) ?? .soulMaster
    }

    var body: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("主题档案")
                            .font(MossTypography.editorial(21, weight: .semibold))
                        Text(theme == .moss ? "你的专注岛正在形成自己的地貌。" : "用同一份专注记录，生成你的修炼形态。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(theme.title, systemImage: theme.symbol)
                        .font(MossTypography.font(10, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MossTheme.sage.opacity(0.10), in: Capsule())
                }

                switch theme {
                case .moss:
                    mossProfile
                case .douluo:
                    douluoProfile
                }
            }
        }
    }

    private var mossProfile: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 22) {
                mossAvatar
                mossSummary
            }
            VStack(alignment: .leading, spacing: 16) {
                mossAvatar
                mossSummary
            }
        }
    }

    private var mossAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            TitleGroup.exploration.color.opacity(0.20),
                            MossTheme.sage.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(TitleGroup.exploration.color.opacity(0.55), lineWidth: 10)
                .rotationEffect(.degrees(20))
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
                .offset(y: 8)
            Image(systemName: "sparkles")
                .foregroundStyle(MossTheme.apricot)
                .offset(x: 42, y: -44)
        }
        .frame(width: 150, height: 150)
        .accessibilityLabel(snapshot.islandStage)
    }

    private var mossSummary: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.islandStage)
                    .font(MossTypography.font(23, weight: .bold))
                Text("累计 \(snapshot.analytics.totalFocus.chineseDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 145), spacing: 9)],
                alignment: .leading,
                spacing: 9
            ) {
                profileStat("已形成区域", "\(snapshot.analytics.titleMetrics.count)", "map.fill")
                profileStat("活跃日", "\(snapshot.analytics.activeDays) 天", "calendar")
                profileStat("最长潮汐", "\(snapshot.analytics.longestStreak) 天", "waveform.path.ecg")
                profileStat("成长证据", "\(snapshot.analytics.achievements.filter(\.isUnlocked).count) 项", "checkmark.seal.fill")
            }

            Text("投入越多的领域，会在岛上形成更大的区域；切换主题不会改变这些地貌数据。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var douluoProfile: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("形态", selection: $avatarFormRaw) {
                ForEach(DouluoAvatarForm.allCases) { form in
                    Label(form.title, systemImage: form.symbol)
                        .tag(form.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 330)

            switch avatarForm {
            case .soulMaster:
                soulMasterProfile
            case .soulBeast:
                soulBeastProfile
            }
        }
    }

    private var soulMasterProfile: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 22) {
                    soulMasterAvatar
                    soulMasterSummary
                }
                VStack(alignment: .leading, spacing: 16) {
                    soulMasterAvatar
                    soulMasterSummary
                }
            }

            if snapshot.soulRingCapacity == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "lock.circle.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("魂环槽位尚未开启")
                            .font(MossTypography.font(11, weight: .bold))
                        Text("达到 10 级后开启第一个魂环槽位。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(11)
                .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
            } else if !snapshot.equippedSoulRings.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("已装备魂环 · \(snapshot.rank.realm.title)最多 \(snapshot.soulRingCapacity) 个")
                            .font(MossTypography.font(11, weight: .bold))
                        Spacer()
                        Text("\(snapshot.equippedSoulRings.count) / \(snapshot.soulRingCapacity)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 9)],
                        spacing: 9
                    ) {
                        ForEach(snapshot.equippedSoulRings) { ring in
                            ringChip(ring)
                        }
                    }
                }
            }

            if !snapshot.unequippedSoulRingCandidates.isEmpty {
                DisclosureGroup(isExpanded: $isShowingRingCandidates) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("这些领域继续保留投入与年限，但在提升魂力等级、开启新槽位前不会显示为已装备魂环。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 9)],
                            spacing: 9
                        ) {
                            ForEach(snapshot.unequippedSoulRingCandidates) { ring in
                                ringCandidateChip(ring)
                            }
                        }
                    }
                    .padding(.top, 9)
                } label: {
                    Label(
                        "候选领域 · \(snapshot.unequippedSoulRingCandidates.count) 个",
                        systemImage: "tray.full.fill"
                    )
                    .font(MossTypography.font(11, weight: .semibold))
                }
                .tint(MossTheme.sage)
            }

            soulSpiritSection

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 185), spacing: 9)],
                spacing: 9
            ) {
                componentTile(
                    "魂骨",
                    snapshot.soulBoneSlots.isEmpty
                        ? "每 2 项修炼功勋解锁一块"
                        : snapshot.soulBoneSlots.joined(separator: " · "),
                    "shield.lefthalf.filled"
                )
                componentTile("斗铠", snapshot.battleArmorTitle, "figure.arms.open")
                componentTile("机甲", snapshot.mechaTitle, "gearshape.2.fill")
            }

            trainingPlan

            organizationSection

            if !snapshot.archivedSoulRings.isEmpty || !snapshot.archivedSoulSpirits.isEmpty {
                DisclosureGroup(isExpanded: $isShowingArchivedGrowth) {
                    VStack(alignment: .leading, spacing: 11) {
                        if !snapshot.archivedSoulSpirits.isEmpty {
                            Text("封存魂灵")
                                .font(MossTypography.font(10, weight: .bold))
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 170), spacing: 9)],
                                spacing: 9
                            ) {
                                ForEach(snapshot.archivedSoulSpirits) { spirit in
                                    spiritChip(spirit)
                                }
                            }
                        }
                        if !snapshot.archivedSoulRings.isEmpty {
                            Text("封存魂环")
                                .font(MossTypography.font(10, weight: .bold))
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 150), spacing: 9)],
                                spacing: 9
                            ) {
                                ForEach(snapshot.archivedSoulRings) { ring in
                                    ringChip(ring)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Label(
                        "历史图鉴 · \(snapshot.archivedSoulSpirits.count) 个项目，"
                            + "\(snapshot.archivedSoulRings.count) 个任务",
                        systemImage: "archivebox.fill"
                    )
                    .font(MossTypography.font(11, weight: .semibold))
                }
                .tint(MossTheme.sage)
            }
        }
    }

    private var organizationSection: some View {
        DisclosureGroup(isExpanded: $isShowingOrganizations) {
            VStack(alignment: .leading, spacing: 11) {
                Text("个人修炼是核心；组织只承接更大规模的项目与长期积累，不替代魂师等级、魂环和装备。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(snapshot.organizationNodes) { node in
                        organizationTile(node)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Label("势力与组织", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(MossTypography.font(11, weight: .semibold))
                Spacer()
                Text("当前舞台 · \(snapshot.currentAffiliation)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if snapshot.organizationPower > 0 {
                    Text("+\(snapshot.organizationPower.formatted())")
                        .font(MossTypography.font(9, weight: .bold))
                        .foregroundStyle(MossTheme.apricot)
                        .monospacedDigit()
                }
            }
        }
        .tint(MossTheme.sage)
        .padding(13)
        .background(MossTheme.quietFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
    }

    private func organizationTile(_ node: ThemeOrganizationNode) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: node.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(node.isUnlocked ? MossTheme.sage : .secondary)
                    .frame(width: 29, height: 29)
                    .background(
                        (node.isUnlocked ? MossTheme.sage : Color.secondary)
                            .opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 9)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(node.title)
                        .font(MossTypography.font(11, weight: .bold))
                    Text(node.isUnlocked ? "已进入" : "尚未解锁")
                        .font(.caption2)
                        .foregroundStyle(node.isUnlocked ? MossTheme.sage : .secondary)
                }

                Spacer()

                Text("+\(node.powerBonus.formatted())")
                    .font(MossTypography.font(9, weight: .bold))
                    .foregroundStyle(node.isUnlocked ? MossTheme.apricot : .secondary)
                    .monospacedDigit()
            }

            Text(node.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ProgressView(value: node.progress)
                .tint(node.isUnlocked ? MossTheme.sage : MossTheme.mint)
        }
        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
        .padding(11)
        .background(MossTheme.card.opacity(node.isUnlocked ? 0.72 : 0.38), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    node.isUnlocked ? MossTheme.sage.opacity(0.20) : Color.secondary.opacity(0.08),
                    lineWidth: 1
                )
        }
    }

    private var trainingPlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("主动修炼搭配")
                        .font(MossTypography.font(12, weight: .bold))
                    Text("预计增益按任务默认时长、领域互补、项目归属与装备路线计算。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("协同战力 +\(snapshot.synergyPower.formatted())")
                    .font(MossTypography.font(10, weight: .bold))
                    .foregroundStyle(MossTheme.apricot)
            }

            if snapshot.trainingRecommendations.isEmpty {
                Text("当前没有可执行的搭配任务；新建或恢复项目后会自动生成建议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 7)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 230), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(snapshot.trainingRecommendations) { recommendation in
                        recommendationCard(recommendation)
                    }
                }
            }
        }
        .padding(13)
        .background(MossTheme.sage.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(MossTheme.sage.opacity(0.12), lineWidth: 1)
        }
    }

    private func recommendationCard(_ recommendation: ThemeTrainingRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    recommendation.title,
                    systemImage: recommendationSymbol(recommendation.route)
                )
                .font(MossTypography.font(11, weight: .bold))
                .foregroundStyle(MossTheme.sage)
                Spacer()
                Text("预计 +\(recommendation.expectedPowerGain)")
                    .font(MossTypography.font(9, weight: .bold))
                    .foregroundStyle(MossTheme.apricot)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.taskTitle)
                    .font(MossTypography.font(13, weight: .bold))
                    .lineLimit(1)
                Text(recommendation.projectTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(recommendation.reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Button("开始修炼") {
                guard let task = snapshot.tasks.first(where: {
                    $0.id == recommendation.taskID
                }) else { return }
                store.start(task: task)
            }
            .buttonStyle(CapsuleButtonStyle(prominent: true))
            .disabled(store.phase != .idle)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .padding(12)
        .background(MossTheme.card.opacity(0.62), in: RoundedRectangle(cornerRadius: 13))
    }

    private func recommendationSymbol(_ route: ThemeTrainingRoute) -> String {
        switch route {
        case .mecha: "gearshape.2.fill"
        case .soulSpirit: "bird.fill"
        case .synergy: "link.circle.fill"
        }
    }

    private var soulSpiritSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("当前魂灵 · 由未归档的大项目生成")
                    .font(MossTypography.font(11, weight: .bold))
                Spacer()
                Text("\(snapshot.activeSoulSpirits.count) 个")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if snapshot.activeSoulSpirits.isEmpty {
                Text("创建一个项目并开始修炼后，这里会生成魂灵。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 170), spacing: 9)],
                    spacing: 9
                ) {
                    ForEach(snapshot.activeSoulSpirits) { spirit in
                        spiritChip(spirit)
                    }
                }
            }
        }
    }

    private var soulMasterAvatar: some View {
        ZStack {
            ForEach(snapshot.equippedSoulRings.indices, id: \.self) { index in
                Circle()
                    .stroke(
                        index == 0 ? MossTheme.sage : TitleGroup.exploration.color,
                        style: StrokeStyle(lineWidth: 2, dash: [4 + CGFloat(index), 4])
                    )
                    .frame(
                        width: 140 - CGFloat(index * 11),
                        height: 140 - CGFloat(index * 11)
                    )
                    .rotationEffect(.degrees(Double(index * 24)))
            }
            Circle()
                .fill(MossTheme.card.opacity(0.88))
                .frame(width: 76, height: 76)
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 43, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
        }
        .frame(width: 150, height: 150)
        .accessibilityLabel("\(snapshot.rank.level) 级\(snapshot.rank.realm.title)")
    }

    private var soulMasterSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Lv.\(snapshot.rank.level)")
                    .font(MossTypography.font(26, weight: .bold))
                    .monospacedDigit()
                Text(snapshot.rank.realm.title)
                    .font(MossTypography.font(16, weight: .bold))
                    .foregroundStyle(MossTheme.sage)
            }

            if snapshot.martialSouls.isEmpty {
                Text("完成第一次有效修炼后觉醒武魂")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 7) {
                    ForEach(snapshot.martialSouls) { soul in
                        Label(soul.group.title, systemImage: soul.group.symbol)
                            .font(MossTypography.font(10, weight: .semibold))
                            .foregroundStyle(soul.group.color)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(soul.group.color.opacity(0.10), in: Capsule())
                    }
                }
                Text(snapshot.martialSouls.count > 1 ? "双生武魂已觉醒" : "主武魂由投入最多的领域生成")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 7) {
                Text("战力")
                    .foregroundStyle(.secondary)
                Text(snapshot.combatPower.formatted())
                    .fontWeight(.bold)
                    .foregroundStyle(MossTheme.apricot)
                    .monospacedDigit()
            }
            .font(MossTypography.font(13, weight: .semibold))

            Label("当前舞台 · \(snapshot.currentAffiliation)", systemImage: "building.2.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var soulBeastProfile: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 22) {
                soulBeastAvatar
                soulBeastSummary
            }
            VStack(alignment: .leading, spacing: 16) {
                soulBeastAvatar
                soulBeastSummary
            }
        }
    }

    private var soulBeastAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            TitleGroup.exploration.color.opacity(0.30),
                            MossTheme.card
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 74
                    )
                )
            Circle()
                .stroke(TitleGroup.exploration.color.opacity(0.45), lineWidth: 2)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(TitleGroup.exploration.color)
        }
        .frame(width: 145, height: 145)
    }

    private var soulBeastSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(snapshot.rank.soulRingTier.title.replacingOccurrences(of: "魂环", with: "魂兽"))
                .font(MossTypography.font(22, weight: .bold))
            Text(snapshot.rank.formattedSoulRingYears)
                .font(MossTypography.font(28, weight: .bold))
                .foregroundStyle(TitleGroup.exploration.color)
                .monospacedDigit()
            Text("魂兽形态只使用总有效专注时长计算年限，不配置魂环、魂骨或装备。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ringChip(_ ring: ThemeSoulRing) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(MossTheme.sage.opacity(0.45), lineWidth: 3)
                Circle()
                    .fill(MossTheme.sage.opacity(0.10))
                    .padding(5)
            }
            .frame(width: 29, height: 29)

            VStack(alignment: .leading, spacing: 2) {
                Text(ring.title)
                    .font(MossTypography.font(10, weight: .bold))
                    .lineLimit(1)
                Text("\(ring.rank.soulRingTier.title) · \(ring.rank.formattedSoulRingYears)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if ring.isArchived {
                    Text(archivedLabel(ring.archivedAt))
                        .font(MossTypography.font(8, weight: .semibold))
                        .foregroundStyle(MossTheme.apricot)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 11))
    }

    private func ringCandidateChip(_ ring: ThemeSoulRing) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "circle.dotted")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 29, height: 29)
            VStack(alignment: .leading, spacing: 2) {
                Text(ring.title)
                    .font(MossTypography.font(10, weight: .bold))
                    .lineLimit(1)
                Text("候选 · \(ring.duration.compactDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 11))
    }

    private func spiritChip(_ spirit: ThemeSoulSpirit) -> some View {
        HStack(spacing: 10) {
            Image(systemName: spirit.symbol)
                .foregroundStyle(spirit.isArchived ? .secondary : MossTheme.sage)
                .frame(width: 31, height: 31)
                .background(
                    (spirit.isArchived ? Color.primary.opacity(0.50) : MossTheme.sage)
                        .opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 9)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(spirit.title)
                    .font(MossTypography.font(10, weight: .bold))
                    .lineLimit(1)
                Text("\(spirit.taskCount) 个任务 · \(spirit.duration.compactDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if spirit.isArchived {
                    Text(archivedLabel(spirit.archivedAt))
                        .font(MossTypography.font(8, weight: .semibold))
                        .foregroundStyle(MossTheme.apricot)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 11))
    }

    private func archivedLabel(_ date: Date?) -> String {
        guard let date else { return "已封存 · 归档日期未记录" }
        return "封存于 \(date.formatted(.dateTime.year().month().day()))"
    }

    private func componentTile(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(MossTheme.sage)
                .frame(width: 31, height: 31)
                .background(MossTheme.sage.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MossTypography.font(10, weight: .bold))
                Text(value)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
    }

    private func profileStat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(MossTheme.sage)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(MossTypography.font(12, weight: .bold))
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct FocusCultivationRankCard: View {
    let rank: FocusCultivationRank
    @State private var isShowingRules = false

    private let ruleColumns = [
        GridItem(.adaptive(minimum: 128), spacing: 9)
    ]

    private var nextLevelText: String {
        guard rank.level < FocusCultivationRank.maximumLevel else {
            return "已抵达一万小时之巅"
        }
        return "距 \(rank.level + 1) 级还需 \(rank.durationToNextLevel.compactDuration)"
    }

    private var nextRealmText: String {
        guard let nextRealm = rank.nextRealm else {
            return "当前境界已达极限"
        }
        return "下一境界 · \(nextRealm.title)（\(nextRealm.lowerBound) 级）"
            + " · 还需 \(rank.durationToNextRealm.compactDuration)"
    }

    private var ringColor: Color {
        switch rank.soulRingTier {
        case .nascent, .tenYear: .secondary
        case .hundredYear: .yellow
        case .thousandYear: TitleGroup.exploration.color
        case .tenThousandYear: Color(red: 0.22, green: 0.24, blue: 0.30)
        case .hundredThousandYear: MossTheme.brick
        case .millionYear: MossTheme.apricot
        }
    }

    var body: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("万时修炼体系")
                            .font(MossTypography.editorial(21, weight: .semibold))
                        Text("修炼等级只依据有效修炼时长，不改变你的原始记录。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("1 小时 = 100 年魂环")
                        .font(MossTypography.font(10, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MossTheme.sage.opacity(0.10), in: Capsule())
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        rankSeal
                        rankSummary
                        Spacer(minLength: 18)
                        soulRingSummary
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 16) {
                            rankSeal
                            rankSummary
                        }
                        soulRingSummary
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(nextLevelText)
                        Spacer()
                        Text("\(Int((rank.levelProgress * 100).rounded()))%")
                            .monospacedDigit()
                    }
                    .font(MossTypography.font(10, weight: .semibold))
                    ProgressView(value: rank.levelProgress)
                        .tint(MossTheme.sage)
                    Text(nextRealmText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.55)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { milestoneStrip }
                    VStack(alignment: .leading, spacing: 9) { milestoneStrip }
                }

                DisclosureGroup(isExpanded: $isShowingRules) {
                    LazyVGrid(columns: ruleColumns, alignment: .leading, spacing: 9) {
                        ForEach(FocusRealm.allCases) { realm in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(realm.title)
                                    .font(MossTypography.font(11, weight: .bold))
                                Text(realm.levelRange)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                realm == rank.realm
                                    ? MossTheme.sage.opacity(0.13)
                                    : MossTheme.quietFill,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("查看完整等级表")
                        .font(MossTypography.font(11, weight: .semibold))
                }
                .tint(MossTheme.sage)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var rankSeal: some View {
        ZStack {
            Circle()
                .fill(MossTheme.sage.opacity(0.12))
            Circle()
                .stroke(MossTheme.sage.opacity(0.30), lineWidth: 1)
            Circle()
                .trim(from: 0, to: rank.levelProgress)
                .stroke(
                    MossTheme.sage,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("LV")
                    .font(MossTypography.font(8, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("\(rank.level)")
                    .font(MossTypography.font(25, weight: .bold))
                    .monospacedDigit()
            }
        }
        .frame(width: 78, height: 78)
        .accessibilityLabel("\(rank.level) 级，\(rank.realm.title)")
    }

    private var rankSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rank.realm.title)
                .font(MossTypography.font(22, weight: .bold))
            Text("魂力等级 \(rank.level) / \(FocusCultivationRank.maximumLevel)")
                .font(MossTypography.font(11, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
            Text("累计 \(rank.totalDuration.chineseDuration)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var soulRingSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.25), lineWidth: 8)
                Circle()
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 3, dash: [3, 3]))
                    .padding(7)
                Circle()
                    .fill(ringColor.opacity(0.18))
                    .padding(15)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(rank.soulRingTier.title)
                    .font(MossTypography.font(13, weight: .bold))
                Text(rank.formattedSoulRingYears)
                    .font(MossTypography.font(16, weight: .bold))
                    .foregroundStyle(ringColor)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(ringColor.opacity(0.075), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(ringColor.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var milestoneStrip: some View {
        rankMilestone("1,000h", "十万年魂环")
        Divider().frame(height: 30)
        rankMilestone("约 7,500h", "90 级 · 封号斗罗")
        Divider().frame(height: 30)
        rankMilestone("10,000h", "99 级 · 极限斗罗 · 百万年")
    }

    private func rankMilestone(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MossTypography.font(12, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

private struct YearSealCard: View {
    let analytics: FocusAnalyticsSnapshot
    let theme: GrowthTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Date.now.formatted(.dateTime.year())) 年度印记")
                        .font(MossTypography.font(11, weight: .bold))
                        .tracking(0.7)
                    Text("这一年留下的有效投入")
                        .font(MossTypography.font(10))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Image(systemName: "seal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }

            Text(analytics.currentYearFocus.compactDuration)
                .font(MossTypography.editorial(35, weight: .semibold))
                .monospacedDigit()

            HStack(spacing: 16) {
                Label("\(analytics.currentYearActiveDays) 个活跃日", systemImage: "calendar")
                Label("全部 \(analytics.completionCount) 段", systemImage: "checkmark")
            }
            .font(MossTypography.font(10, weight: .medium))
            .foregroundStyle(.white.opacity(0.70))

            if let next = analytics.nextAchievement {
                let presentation = theme.achievementPresentation(for: next)
                Divider().overlay(.white.opacity(0.18))
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("\(theme.nextMilestonePrefix) · \(presentation.title)")
                        Spacer()
                        Text("\(Int((next.progress * 100).rounded()))%")
                    }
                    .font(MossTypography.font(10, weight: .semibold))
                    ProgressView(value: next.progress)
                        .tint(.white.opacity(0.88))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 206, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    MossTheme.sageDeep,
                    MossTheme.sageDeep.opacity(0.90),
                    MossTheme.sage.opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "年度印记，\(analytics.currentYearFocus.chineseDuration)，"
            + "\(analytics.currentYearActiveDays) 个活跃日"
        )
    }
}

private struct MonthlyChronicleCard: View {
    let months: [FocusMonthRecord]
    let peakDay: FocusDayRecord?
    let peakMonth: FocusMonthRecord?
    let longestStreak: Int

    private var maxDuration: TimeInterval {
        max(1, months.map(\.duration).max() ?? 1)
    }

    var body: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("积累编年史")
                            .font(MossTypography.editorial(21, weight: .semibold))
                        Text("过去十二个月，每一柱都是被兑现的时间。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("12 MONTHS")
                        .font(MossTypography.font(9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(MossTheme.sage)
                }

                Chart {
                    ForEach(months, id: \.date) { month in
                        BarMark(
                            x: .value("月份", month.date, unit: .month),
                            y: .value("小时", month.duration / 3_600)
                        )
                        .foregroundStyle(
                            month.duration == maxDuration
                                ? MossTheme.sage
                                : MossTheme.sage.opacity(month.duration > 0 ? 0.38 : 0.10)
                        )
                        .cornerRadius(5)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.10))
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text("\(Int(hours))h")
                            }
                        }
                    }
                }
                .frame(height: 190)

                HStack(spacing: 0) {
                    chronicleEvidence(
                        value: peakMonth?.duration.compactDuration ?? "—",
                        label: peakMonth.map {
                            "最佳月份 · \($0.date.formatted(.dateTime.month(.wide)))"
                        } ?? "最佳月份"
                    )
                    Divider().frame(height: 36)
                    chronicleEvidence(
                        value: peakDay?.duration.compactDuration ?? "—",
                        label: peakDay.map {
                            "最高单日 · \($0.date.formatted(.dateTime.month().day()))"
                        } ?? "最高单日"
                    )
                    Divider().frame(height: 36)
                    chronicleEvidence(
                        value: "\(longestStreak) 天",
                        label: "最长连续"
                    )
                }
            }
        }
    }

    private func chronicleEvidence(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(MossTypography.font(14, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(MossTypography.font(9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}

private struct AchievementMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 31, height: 31)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(MossTypography.font(16, weight: .bold))
                    .monospacedDigit()
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MossTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .mossJellyHover(scale: 1.035, lift: 3, glow: 0.13)
    }
}

private struct AchievementEvidenceCard: View {
    let achievement: Achievement
    let theme: GrowthTheme

    private var presentation: AchievementPresentation {
        theme.achievementPresentation(for: achievement)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: presentation.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MossTheme.apricot)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(MossTheme.mint)
            }
            Text(presentation.title)
                .font(MossTypography.font(13, weight: .bold))
            Text(presentation.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(
                achievement.unlockedAt?.formatted(.dateTime.year().month().day())
                    ?? "已经解锁"
            )
            .font(MossTypography.font(9, weight: .semibold))
            .foregroundStyle(MossTheme.sage)
        }
        .padding(14)
        .background(MossTheme.apricot.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(MossTheme.apricot.opacity(0.16), lineWidth: 1)
        )
        .mossJellyHover(scale: 1.035, lift: 3, glow: 0.13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title)，已解锁，\(presentation.subtitle)")
    }
}

private struct NextMilestoneRow: View {
    let achievement: Achievement
    let theme: GrowthTheme

    private var presentation: AchievementPresentation {
        theme.achievementPresentation(for: achievement)
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: presentation.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
                .frame(width: 36, height: 36)
                .background(MossTheme.sage.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(theme.nextMilestonePrefix) · \(presentation.title)")
                        .font(MossTypography.font(12, weight: .bold))
                    Spacer()
                    Text("\(Int((achievement.progress * 100).rounded()))%")
                        .font(MossTypography.font(10, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                }
                Text(presentation.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ProgressView(value: achievement.progress)
                    .tint(MossTheme.sage)
            }
        }
        .padding(13)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 15))
        .mossJellyHover(scale: 1.025, lift: 2, glow: 0.10)
        .accessibilityElement(children: .combine)
    }
}

private struct IslandNodeFrame {
    let center: CGPoint
    let width: CGFloat
    var rect: CGRect {
        CGRect(x: center.x - width / 2, y: center.y - width * 0.38, width: width, height: width * 0.76)
    }
}

private struct IslandMapCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let metrics: [TitleMetric]
    let onSelect: (TitleMetric) -> Void

    var body: some View {
        MossCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("领域地形")
                            .font(MossTypography.editorial(20, weight: .semibold))
                        Text("区域越大，投入越深；点击进入成长档案。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("\(metrics.count) 个区域", systemImage: "map.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MossTheme.sage)
                }

                GeometryReader { proxy in
                    let frames = nodeFrames(in: proxy.size)
                    ZStack {
                        Canvas { context, size in
                            let water = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18)
                            context.fill(water, with: .linearGradient(
                                Gradient(colors: [MossTheme.sage.opacity(0.055), MossTheme.quietFill]),
                                startPoint: .zero,
                                endPoint: CGPoint(x: size.width, y: size.height)
                            ))
                            for (index, metric) in metrics.enumerated() where index < frames.count {
                                let frame = frames[index]
                                // GraphicsContext filters are cumulative. Isolate each island so
                                // 25 shadows do not stack into an exponentially expensive pipeline.
                                var islandContext = context
                                if index < 8 {
                                    islandContext.addFilter(
                                        .shadow(
                                            color: metric.profile.group.color.opacity(0.12),
                                            radius: 6,
                                            y: 4
                                        )
                                    )
                                }
                                islandContext.fill(
                                    Path(ellipseIn: frame.rect),
                                    with: .linearGradient(
                                        Gradient(colors: [
                                            metric.profile.group.color.opacity(0.62),
                                            metric.profile.group.color.opacity(0.22)
                                        ]),
                                        startPoint: CGPoint(x: frame.rect.midX, y: frame.rect.minY),
                                        endPoint: CGPoint(x: frame.rect.midX, y: frame.rect.maxY)
                                    )
                                )
                            }
                        }

                        ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                            if index < frames.count {
                                let frame = frames[index]
                                Button { onSelect(metric) } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: metric.profile.symbol)
                                            .font(.system(size: max(10, min(18, frame.width * 0.19)), weight: .semibold))
                                        if frame.width >= 57 {
                                            Text(metric.title)
                                                .font(MossTypography.font(max(8, min(11, frame.width * 0.11)), weight: .bold))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                    }
                                    .foregroundStyle(.white)
                                    .frame(width: frame.width, height: frame.width * 0.76)
                                    .contentShape(Ellipse())
                                }
                                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                                .mossJellyHover(scale: 1.10, lift: 2, glow: 0.16)
                                .position(frame.center)
                                .help("\(metric.title) · \(metric.totalDuration.chineseDuration) · \(metric.mastery.title)")
                                .accessibilityLabel("\(metric.title)，\(metric.totalDuration.chineseDuration)，\(metric.mastery.title)")
                            }
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: metrics.count)
                }
                .frame(minHeight: 315)

                HStack(spacing: 12) {
                    ForEach(TitleGroup.allCases) { group in
                        Label(group.title, systemImage: group.symbol)
                            .font(MossTypography.font(9, weight: .semibold))
                            .foregroundStyle(group.color)
                    }
                }
            }
        }
    }

    private func nodeFrames(in size: CGSize) -> [IslandNodeFrame] {
        guard !metrics.isEmpty else { return [] }
        let maxDuration = max(1, metrics.map(\.totalDuration).max() ?? 1)
        return metrics.enumerated().map { index, metric in
            let angle = Double(index) * 2.399963229728653
            let radial = index == 0 ? 0 : 0.13 + 0.31 * sqrt(Double(index) / Double(max(1, metrics.count - 1)))
            let x = size.width * (0.5 + CGFloat(cos(angle) * radial))
            let y = size.height * (0.52 + CGFloat(sin(angle) * radial * 0.86))
            let normalized = sqrt(metric.totalDuration / maxDuration)
            let width = 42 + CGFloat(normalized) * 58
            return IslandNodeFrame(
                center: CGPoint(
                    x: min(size.width - width / 2 - 4, max(width / 2 + 4, x)),
                    y: min(size.height - width * 0.38 - 4, max(width * 0.38 + 4, y))
                ),
                width: width
            )
        }
    }
}
