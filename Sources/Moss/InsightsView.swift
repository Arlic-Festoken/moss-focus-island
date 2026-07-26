import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var selectedTitle: TitleMetric?
    @State private var analytics = FocusAnalyticsSnapshot(sessions: [])

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                pageHeader

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        levelHero.frame(minWidth: 330, maxWidth: 410)
                        IslandMapCard(metrics: analytics.titleMetrics) { selectedTitle = $0 }
                            .frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 18) {
                        levelHero
                        IslandMapCard(metrics: analytics.titleMetrics) { selectedTitle = $0 }
                    }
                }

                metricStrip

                achievementsSection

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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("专注岛拓荒")
                    .font(MossTypography.font(30, weight: .bold))
                Text("每一段真实投入，都在岛上留下地形。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let latest = latestUnlockedAchievement {
                Label("最近解锁 · \(latest.title)", systemImage: latest.symbol)
                    .font(MossTypography.font(12, weight: .semibold))
                    .foregroundStyle(MossTheme.sage)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(MossTheme.sage.opacity(0.1), in: Capsule())
            }
        }
    }

    private var latestUnlockedAchievement: Achievement? {
        analytics.achievements
            .filter(\.isUnlocked)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
            .first
    }

    private var levelHero: some View {
        MossCard(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("专注岛等级")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Lv.\(analytics.level)")
                            .font(MossTypography.font(42, weight: .bold))
                            .foregroundStyle(MossTheme.sage)
                            .monospacedDigit()
                    }
                    Spacer()
                    ZStack {
                        ProgressRing(progress: analytics.levelProgress, lineWidth: 7, tint: MossTheme.sage)
                        Image(systemName: "map.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(MossTheme.sage)
                    }
                    .frame(width: 70, height: 70)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("当前等级 \(analytics.level)")
                    .accessibilityValue("升级进度 \(Int(analytics.levelProgress * 100))%")
                }

                VStack(alignment: .leading, spacing: 7) {
                    ProgressView(value: analytics.levelProgress)
                        .tint(MossTheme.sage)
                    HStack {
                        Text("\(analytics.experience) XP")
                        Spacer()
                        Text("还差 \(analytics.experienceToNextLevel) 分钟升级")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Divider().opacity(0.55)

                HStack(spacing: 0) {
                    heroStat(analytics.totalFocus.compactDuration, "有效专注")
                    Divider().frame(height: 38)
                    heroStat("\(analytics.completionCount)", "完成段数")
                    Divider().frame(height: 38)
                    heroStat("\(analytics.activeDays)", "活跃天")
                }

                let remaining = max(0, 200 * 3_600 - analytics.totalFocus)
                Label(
                    remaining > 0 ? "下一座大陆 · 距 200 小时还差 \(remaining.compactDuration)" : "二百小时大陆已经点亮",
                    systemImage: remaining > 0 ? "map.fill" : "checkmark.seal.fill"
                )
                .font(MossTypography.font(12, weight: .semibold))
                .foregroundStyle(MossTheme.apricot)
            }
        }
    }

    private func heroStat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(MossTypography.font(15, weight: .bold))
                .monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { metricTiles }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) { metricTiles }
        }
    }

    @ViewBuilder private var metricTiles: some View {
        AchievementMetricTile(title: "完成率", value: "\(Int((analytics.completionRate * 100).rounded()))%", icon: "checkmark.circle.fill", tint: MossTheme.mint)
        AchievementMetricTile(title: "当前连续", value: "\(analytics.currentStreak) 天", icon: "flame.fill", tint: MossTheme.apricot)
        AchievementMetricTile(title: "最长连续", value: "\(analytics.longestStreak) 天", icon: "calendar.badge.checkmark", tint: MossTheme.sage)
        AchievementMetricTile(title: "中位单次", value: analytics.medianSession.compactDuration, icon: "timer", tint: TitleGroup.academic.color)
        AchievementMetricTile(title: "岛上区域", value: "\(analytics.titleMetrics.count)", icon: "map.fill", tint: TitleGroup.exploration.color)
    }

    private var achievementsSection: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("成就陈列架").font(.title3.bold())
                        Text("已解锁 \(analytics.achievements.filter(\.isUnlocked).count) / \(analytics.achievements.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("成就只由有效专注解锁")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                    ForEach(analytics.achievements) { achievement in
                        AchievementBadgeView(achievement: achievement)
                    }
                }
            }
        }
    }

    private var personalRecords: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("个人纪录").font(.title3.bold())
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
                    Text("地标排行").font(.title3.bold())
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

private struct AchievementBadgeView: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: achievement.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? MossTheme.apricot : .secondary)
                Spacer()
                Image(systemName: achievement.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .foregroundStyle(achievement.isUnlocked ? MossTheme.mint : .secondary.opacity(0.5))
            }
            Text(achievement.title)
                .font(MossTypography.font(13, weight: .bold))
            Text(achievement.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ProgressView(value: achievement.progress)
                .tint(achievement.isUnlocked ? MossTheme.mint : MossTheme.sage)
        }
        .padding(13)
        .background(
            (achievement.isUnlocked ? MossTheme.apricot.opacity(0.07) : Color.primary.opacity(0.025)),
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(achievement.isUnlocked ? MossTheme.apricot.opacity(0.18) : Color.primary.opacity(0.05))
        )
        .opacity(achievement.isUnlocked ? 1 : 0.66)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title)，\(achievement.isUnlocked ? "已解锁" : "未解锁")")
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
                        Text("岛屿全景").font(.title3.bold())
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
                                Gradient(colors: [TitleGroup.academic.color.opacity(0.07), MossTheme.sage.opacity(0.02)]),
                                startPoint: .zero,
                                endPoint: CGPoint(x: size.width, y: size.height)
                            ))
                            for (index, metric) in metrics.enumerated() where index < frames.count {
                                let frame = frames[index]
                                // GraphicsContext filters are cumulative. Isolate each island so
                                // 25 shadows do not stack into an exponentially expensive pipeline.
                                var islandContext = context
                                islandContext.addFilter(.shadow(color: metric.profile.group.color.opacity(0.18), radius: 8, y: 5))
                                islandContext.fill(
                                    Path(ellipseIn: frame.rect),
                                    with: .linearGradient(
                                        Gradient(colors: [metric.profile.group.color.opacity(0.68), metric.profile.group.color.opacity(0.24)]),
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
