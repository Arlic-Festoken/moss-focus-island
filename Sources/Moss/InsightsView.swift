import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var selectedTitle: TitleMetric?
    @State private var analytics = FocusAnalyticsSnapshot(sessions: [])

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                pageHeader
                bodyOfWorkHero
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
        .onReceive(dataStore.$sessions) { sessions in
            analytics = FocusAnalyticsSnapshot(sessions: sessions)
        }
    }

    private var pageHeader: some View {
        MossPageHeader(
            eyebrow: "Growth Journal",
            title: "成长志",
            subtitle: "不是更多统计，而是你投入过的时间正在形成什么。"
        ) {
            if let latest = analytics.latestUnlockedAchievement {
                Label("最近解锁 · \(latest.title)", systemImage: latest.symbol)
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
                    YearSealCard(analytics: analytics)
                        .frame(width: 330)
                }
                VStack(alignment: .leading, spacing: 20) {
                    bodyOfWorkStatement
                    YearSealCard(analytics: analytics)
                }
            }
        }
    }

    private var bodyOfWorkStatement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你的投入，正在成为可以回望的作品。")
                .font(MossTypography.editorial(29, weight: .semibold))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
            if analytics.totalFocus > 0 {
                (
                    Text("截至今天，你已经为重要的事投入 ")
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
                Text("完成第一段专注后，这里会开始记录你的作品。")
                    .font(MossTypography.font(14))
                    .foregroundStyle(.secondary)
            }
            if let first = analytics.titleMetrics
                .compactMap(\.firstDate)
                .min() {
                Label(
                    "从 \(first.formatted(.dateTime.year().month().day())) 开始生长",
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
                        Text("成长证据")
                            .font(MossTypography.editorial(21, weight: .semibold))
                        Text("每一个里程碑都有日期，也有真实投入作为依据。")
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
                        "证据正在等待第一段投入",
                        systemImage: "leaf",
                        description: Text("完成一段有效专注后，第一块苔藓会留在这里。")
                    )
                    .frame(minHeight: 150)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(unlockedEvidence) { achievement in
                            AchievementEvidenceCard(achievement: achievement)
                        }
                    }
                }

                if let next = analytics.nextAchievement {
                    NextMilestoneRow(achievement: next)
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct YearSealCard: View {
    let analytics: FocusAnalyticsSnapshot

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
                Label("\(analytics.completionCount) 段完成", systemImage: "checkmark")
            }
            .font(MossTypography.font(10, weight: .medium))
            .foregroundStyle(.white.opacity(0.70))

            if let next = analytics.nextAchievement {
                Divider().overlay(.white.opacity(0.18))
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("下一里程碑 · \(next.title)")
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
    }
}

private struct AchievementEvidenceCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: achievement.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MossTheme.apricot)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(MossTheme.mint)
            }
            Text(achievement.title)
                .font(MossTypography.font(13, weight: .bold))
            Text(achievement.subtitle)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title)，已解锁，\(achievement.subtitle)")
    }
}

private struct NextMilestoneRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
                .frame(width: 36, height: 36)
                .background(MossTheme.sage.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("下一里程碑 · \(achievement.title)")
                        .font(MossTypography.font(12, weight: .bold))
                    Spacer()
                    Text("\(Int((achievement.progress * 100).rounded()))%")
                        .font(MossTypography.font(10, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                }
                Text(achievement.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ProgressView(value: achievement.progress)
                    .tint(MossTheme.sage)
            }
        }
        .padding(13)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 15))
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
                                .buttonStyle(.plain)
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
