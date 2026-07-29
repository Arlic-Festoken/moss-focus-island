import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @AppStorage("growthTheme") private var growthThemeRaw = GrowthTheme.douluo.rawValue
    var onOpenTimeline: () -> Void = {}

    private var growthTheme: GrowthTheme {
        GrowthTheme(rawValue: growthThemeRaw) ?? .douluo
    }

    private var metrics: DailyMetrics {
        InsightEngine.todayMetrics(
            sessions: dataStore.sessions,
            interruptions: dataStore.interruptions
        )
    }

    private var isShowingCurrentSession: Bool {
        store.isActive || store.phase == .awaitingReview
    }

    private var analytics: FocusAnalyticsSnapshot {
        dataStore.analyticsSnapshot
    }

    private var currentTaskTotal: TimeInterval {
        guard let taskID = store.currentTaskID else { return 0 }
        return dataStore.totalFocus(for: taskID)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                statusCard

                focusDashboard
            }
            .padding(28)
            .frame(maxWidth: 1160, alignment: .leading)
        }
    }

    private var header: some View {
        MossPageHeader(
            eyebrow: "Today",
            title: greeting,
            subtitle: Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide))
        )
    }

    private var statusCard: some View {
        MossCard(kind: .hero) {
            VStack(alignment: .leading, spacing: 20) {
                heroStatusContent

                Divider().opacity(0.55)

                HStack(spacing: 0) {
                    MossMetric(
                        value: metrics.totalFocus.compactDuration,
                        label: growthTheme == .douluo ? "今日修炼" : "今日投入",
                        symbol: "sun.max.fill",
                        tint: MossTheme.apricot
                    )
                    Divider().frame(height: 34)
                    MossMetric(
                        value: analytics.totalFocus.compactDuration,
                        label: growthTheme == .douluo ? "总修炼" : "全部积累",
                        symbol: "leaf.fill"
                    )
                    Divider().frame(height: 34)
                    MossMetric(
                        value: "\(analytics.activeDays) 天",
                        label: "留下痕迹",
                        symbol: "calendar"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var heroStatusContent: some View {
        if isShowingCurrentSession {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 30) {
                    heroPrimaryContent
                    Spacer(minLength: 20)
                    heroActionContent
                }
                VStack(alignment: .leading, spacing: 20) {
                    heroPrimaryContent
                    heroActionContent
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 18) {
                heroPrimaryContent
                if let next = dataStore.preferredStartTask {
                    idleQuickStart(task: next)
                }
            }
        }
    }

    @ViewBuilder
    private var heroPrimaryContent: some View {
        if isShowingCurrentSession {
            VStack(alignment: .leading, spacing: 8) {
                Text(statusTitle)
                    .font(MossTypography.font(11, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(MossTheme.sage)
                Text(store.displayTime.clockString)
                    .font(MossTypography.font(46, weight: .bold))
                    .monospacedDigit()
                Text("\(store.currentProjectTitle.isEmpty ? store.currentCategory : store.currentProjectTitle) · \(store.currentTaskTitle)")
                    .font(MossTypography.font(13, weight: .medium))
                    .foregroundStyle(.secondary)
                Label(
                    "当前领域 \(currentTaskTotal.compactDuration)",
                    systemImage: "map.fill"
                )
                .font(MossTypography.font(11, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
            }
        } else {
            VStack(alignment: .leading, spacing: 9) {
                Text("YOUR BODY OF WORK")
                    .font(MossTypography.font(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(MossTheme.sage)
                Text(idleHeroTitle)
                    .font(MossTypography.editorial(32, weight: .semibold))
                    .tracking(-0.45)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    metrics.completedCount > 0
                        ? (
                            growthTheme == .douluo
                                ? "今天已经完成 \(metrics.completedCount) 次修炼，下一次会继续凝聚魂力。"
                                : "今天已经完成 \(metrics.completedCount) 段，下一段会继续长在这份积累上。"
                        )
                        : (
                            growthTheme == .douluo
                                ? "今天还没有开始修炼，但过去凝聚的魂力不会归零。"
                                : "今天还没有开始，但过去的投入没有归零。"
                        )
                )
                .font(MossTypography.font(13))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 610, alignment: .leading)
        }
    }

    @ViewBuilder
    private var heroActionContent: some View {
        if isShowingCurrentSession {
            HStack(spacing: 18) {
                TodayFocusControls()
                ProgressRing(
                    progress: store.progress,
                    lineWidth: 8,
                    tint: store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage
                )
                .frame(width: 76, height: 76)
                .overlay {
                    Image(
                        systemName: store.phase == .paused
                            ? "pause.fill"
                            : store.phase == .breakTime ? "cup.and.saucer.fill" : "leaf.fill"
                    )
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage)
                }
            }
        }
    }

    private func idleQuickStart(task: FocusTask) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                quickStartIdentity(task: task)
                Spacer(minLength: 24)
                quickStartButtons(task: task)
            }
            VStack(alignment: .leading, spacing: 13) {
                quickStartIdentity(task: task)
                quickStartButtons(task: task)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            MossTheme.sage.opacity(0.065),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MossTheme.sage.opacity(0.14), lineWidth: 1)
        }
    }

    private func quickStartIdentity(task: FocusTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.forward.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
                .frame(width: 38, height: 38)
                .background(
                    MossTheme.sage.opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(growthTheme == .douluo ? "接着修炼 \(task.title)" : "接着做 \(task.title)")
                    .font(MossTypography.font(14, weight: .bold))
                Text(
                    growthTheme == .douluo
                        ? "\(task.timerActivity.title) · 从熟悉的领域开始修炼"
                        : "\(task.timerActivity.title) · 从熟悉的任务开始"
                )
                    .font(MossTypography.font(10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func quickStartButtons(task: FocusTask) -> some View {
        HStack(spacing: 8) {
            Button("先做 5 分钟") {
                store.start(task: task, mode: .ignition)
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot))

            Button(growthTheme == .douluo ? "开始修炼" : "开始专注") {
                store.start(task: task)
            }
            .buttonStyle(CapsuleButtonStyle(prominent: true))
        }
    }

    private var idleHeroTitle: String {
        guard analytics.totalFocus > 0 else {
            return growthTheme == .douluo
                ? "从第一次修炼开始，凝聚属于你的魂力。"
                : "从第一段开始，让时间留下形状。"
        }
        return growthTheme == .douluo
            ? "把今天的一次修炼，炼成新的魂力。"
            : "把今天的一小段，续进你的长期积累。"
    }

    private var statusTitle: String {
        switch store.phase {
        case .preparing: growthTheme == .douluo ? "正在进入修炼状态" : "正在进入状态"
        case .focusing: growthTheme == .douluo ? "此刻正在修炼" : "此刻正在专注"
        case .paused: growthTheme == .douluo ? "修炼已暂停" : "专注已暂停"
        case .breakTime: "休息中"
        case .awaitingReview: growthTheme == .douluo ? "等待记录本次修炼" : "等待记录这一段"
        case .idle: growthTheme == .douluo ? "今天已经修炼" : "今天已经专注"
        }
    }

    private var taskCard: some View {
        TodayTaskLibraryView()
    }

    private var focusDashboard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                taskCard
                    .frame(minWidth: 520, maxWidth: .infinity)
                insightRail
                    .frame(width: 340)
            }
            VStack(alignment: .leading, spacing: 18) {
                taskCard
                insightRail
            }
        }
    }

    private var insightRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            FocusWeatherCard(metrics: metrics)
                .frame(maxWidth: .infinity, alignment: .leading)
            DailyFeedbackCard(metrics: metrics)
                .frame(maxWidth: .infinity, alignment: .leading)
            TodayTimelineCard(
                sessions: dataStore.sessions,
                onOpenTimeline: onOpenTimeline
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 11 { return "早上好，智康。" }
        if hour < 18 { return "下午好，智康。" }
        return "晚上好，智康。"
    }
}

private struct TodayFocusControls: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) { controls }
            VStack(alignment: .leading, spacing: 9) { controls }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("当前专注操作")
    }

    @ViewBuilder
    private var controls: some View {
        switch store.phase {
        case .preparing:
            Button {
                store.cancelStart()
            } label: {
                Label("取消开始", systemImage: "xmark")
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick))
        case .focusing:
            Button {
                store.pause()
            } label: {
                Label("暂停", systemImage: "pause.fill")
            }
            .buttonStyle(CapsuleButtonStyle())

            Button {
                store.beginOrReturnFromInterruption()
            } label: {
                Label("记录打断", systemImage: "arrow.up.right")
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot))

            Button {
                store.requestEnd()
            } label: {
                Label("结束并记录", systemImage: "stop.fill")
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick, prominent: true, prominentForeground: .white))
        case .paused:
            Button {
                store.resume()
            } label: {
                Label("继续", systemImage: "play.fill")
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.mint, prominent: true))

            Button {
                store.requestEnd()
            } label: {
                Label("结束并记录", systemImage: "stop.fill")
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick, prominent: true, prominentForeground: .white))
        case .breakTime:
            Button {
                store.skipBreak()
            } label: {
                Label("结束休息", systemImage: "forward.end.fill")
            }
            .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot, prominent: true))
        case .awaitingReview:
            Button {
                store.presentReview()
            } label: {
                Label("完成记录", systemImage: "checkmark")
            }
            .buttonStyle(CapsuleButtonStyle(prominent: true))
        case .idle:
            EmptyView()
        }
    }
}

struct CategoryGlyph: View {
    let category: String
    var symbol: String? = nil

    private var resolvedSymbol: String {
        if let symbol { return symbol }
        if category.contains("英语") { return "text.bubble.fill" }
        if category.contains("项目") || category.contains("开发") { return "point.3.connected.trianglepath.dotted" }
        if category.contains("阅读") { return "book.closed.fill" }
        if category.contains("健身") || category.contains("跑步") { return "figure.run" }
        return "leaf.fill"
    }

    var body: some View {
        Image(systemName: resolvedSymbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(MossTheme.sage)
            .frame(width: 38, height: 38)
            .background(MossTheme.sage.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FocusWeatherCard: View {
    let metrics: DailyMetrics

    private var weather: (title: String, advice: String) {
        InsightEngine.weather(for: metrics)
    }

    var body: some View {
        MossCard(kind: .quiet) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "sun.haze.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(MossTheme.apricot, MossTheme.sage.opacity(0.5))
                    Spacer()
                    Text("透明规则推断")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("专注天气")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(weather.title)
                    .font(MossTypography.editorial(20, weight: .semibold))
                Text(weather.advice)
                    .font(MossTypography.font(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TodayTimelineCard: View {
    let sessions: [FocusSession]
    let onOpenTimeline: () -> Void

    private var today: [FocusSession] {
        sessions
            .filter { $0.startedAt >= Date.now.dayStart }
            .sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("专注轨迹")
                        .font(MossTypography.editorial(20, weight: .semibold))
                    Spacer()
                    Button("查看全部", action: onOpenTimeline)
                        .buttonStyle(MossJellyPlainButtonStyle())
                        .mossJellyHover(scale: 1.018, lift: 1.5, glow: 0.08)
                    .font(.caption)
                }
                if today.isEmpty {
                    Text("第一段开始后，今天的学习波形会长在这里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 130)
                } else {
                    ForEach(today.prefix(5)) { session in
                        TimelineRow(session: session)
                    }
                }
            }
        }
    }
}

struct TimelineRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
                Text(session.startedAt.formatted(.dateTime.hour().minute()))
                    .font(MossTypography.font(12))
                    .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .leading)
            RoundedRectangle(cornerRadius: 3)
                .fill(session.mode == .ignition ? MossTheme.apricot : MossTheme.sage)
                .frame(width: min(150, max(28, session.actualFocusDuration / 18)), height: 7)
                .overlay(alignment: .trailing) {
                    if session.status == .completed && session.pausedDuration < 10 {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(MossTheme.sage)
                            .offset(x: 13)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                        Text(session.taskTitle)
                            .font(MossTypography.font(13, weight: .semibold))
                    .lineLimit(1)
                Text("\(session.category) · \(session.actualFocusDuration.compactDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct DailyFeedbackCard: View {
    let metrics: DailyMetrics

    var body: some View {
        MossCard(kind: .quiet) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(MossTheme.sage)
                    Text("今日反馈")
                        .font(MossTypography.editorial(20, weight: .semibold))
                }
                ForEach(Array(InsightEngine.feedback(for: metrics).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(MossTheme.sage)
                            .frame(width: 22, height: 22)
                            .background(MossTheme.sage.opacity(0.1), in: Circle())
                        Text(item)
                            .font(MossTypography.font(13))
                            .foregroundStyle(index == 2 ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
