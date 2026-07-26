import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    var onOpenTimeline: () -> Void = {}
    private var activeTasks: [FocusTask] {
        dataStore.startableTasks
    }

    private var activeProjects: [FocusProject] {
        dataStore.projects.filter { !$0.archived }
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
        FocusAnalyticsSnapshot(sessions: dataStore.sessions)
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

                taskAndWeather
                timelineAndFeedback
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

                Divider().opacity(0.55)

                HStack(spacing: 0) {
                    MossMetric(
                        value: metrics.totalFocus.compactDuration,
                        label: "今日投入",
                        symbol: "sun.max.fill",
                        tint: MossTheme.apricot
                    )
                    Divider().frame(height: 34)
                    MossMetric(
                        value: analytics.totalFocus.compactDuration,
                        label: "全部积累",
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
                        ? "今天已经完成 \(metrics.completedCount) 段，下一段会继续长在这份积累上。"
                        : "今天还没有开始，但过去的投入没有归零。"
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
        } else if let next = dataStore.preferredStartTask {
            VStack(alignment: .trailing, spacing: 11) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("继续 \(next.title)")
                        .font(MossTypography.font(15, weight: .bold))
                    Text(next.timerActivity.title)
                        .font(MossTypography.font(10))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("先做 5 分钟") {
                        store.start(task: next, mode: .ignition)
                    }
                    .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot))
                    Button("开始下一段") {
                        store.start(task: next)
                    }
                    .buttonStyle(CapsuleButtonStyle(prominent: true))
                }
            }
        }
    }

    private var idleHeroTitle: String {
        guard analytics.totalFocus > 0 else {
            return "从第一段开始，让时间留下形状。"
        }
        return "把今天的一小段，加入 \(analytics.totalFocus.chineseDuration) 里。"
    }

    private var statusTitle: String {
        switch store.phase {
        case .preparing: "正在进入状态"
        case .focusing: "此刻正在专注"
        case .paused: "专注已暂停"
        case .breakTime: "休息中"
        case .awaitingReview: "等待记录这一段"
        case .idle: "今天已经专注"
        }
    }

    private var taskCard: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("今天的任务")
                        .font(MossTypography.editorial(20, weight: .semibold))
                    Spacer()
                    Text("\(activeTasks.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if activeTasks.isEmpty {
                    ContentUnavailableView(
                        "今天还很清爽",
                        systemImage: "leaf",
                        description: Text("添加一个边界清楚的小任务。")
                    )
                    .frame(height: 160)
                } else {
                    ForEach(activeProjects) { project in
                        let projectTasks = activeTasks.filter { $0.projectID == project.id }
                        if !projectTasks.isEmpty {
                            ProjectTaskSection(project: project, tasks: projectTasks)
                        }
                    }
                    let ungrouped = activeTasks.filter { $0.projectID == nil }
                    if !ungrouped.isEmpty {
                        ProjectTaskSection(
                            project: FocusProject(title: "未分类", symbol: "tray.fill"),
                            tasks: ungrouped,
                            isSynthetic: true
                        )
                    }
                }
            }
        }
    }

    private var taskAndWeather: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                taskCard
                    .frame(minWidth: 440, maxWidth: .infinity)
                FocusWeatherCard(metrics: metrics)
                    .frame(width: 300)
            }
            VStack(alignment: .leading, spacing: 18) {
                taskCard
                FocusWeatherCard(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var timelineAndFeedback: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                TodayTimelineCard(
                    sessions: dataStore.sessions,
                    onOpenTimeline: onOpenTimeline
                )
                    .frame(minWidth: 400, maxWidth: .infinity)
                DailyFeedbackCard(metrics: metrics)
                    .frame(width: 360)
            }
            VStack(alignment: .leading, spacing: 18) {
                TodayTimelineCard(
                    sessions: dataStore.sessions,
                    onOpenTimeline: onOpenTimeline
                )
                DailyFeedbackCard(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

private struct ProjectTaskSection: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    let project: FocusProject
    let tasks: [FocusTask]
    var isSynthetic = false
    @State private var isAddingTask = false
    @State private var isEditingProject = false

    private var totalFocus: TimeInterval {
        isSynthetic
            ? tasks.reduce(0) { $0 + dataStore.totalFocus(for: $1.id) }
            : dataStore.totalFocus(forProjectID: project.id)
    }

    private var containsCurrentTask: Bool {
        guard store.phase != .idle else { return false }
        if isSynthetic {
            return tasks.contains(where: { $0.id == store.currentTaskID })
        }
        return store.currentProjectID == project.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: project.symbol)
                    .foregroundStyle(MossTheme.sage)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.title)
                        .font(MossTypography.font(14, weight: .bold))
                    Text("\(tasks.count) 个任务 · \(totalFocus.compactDuration)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isAddingTask = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                if !isSynthetic {
                    Menu {
                        Button("编辑项目") { isEditingProject = true }
                            .disabled(containsCurrentTask)
                        Button("归档项目") {
                            dataStore.archiveProject(id: project.id, archived: true)
                        }
                        .disabled(containsCurrentTask)
                        if containsCurrentTask {
                            Divider()
                            Text("请先结束该项目中的当前专注")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.top, 4)

            ForEach(tasks) { task in
                TaskCapsuleRow(task: task)
                if task.id != tasks.last?.id {
                    Divider().opacity(0.55)
                }
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $isAddingTask) {
            TaskEditorView(projectID: isSynthetic ? nil : project.id)
        }
        .sheet(isPresented: $isEditingProject) {
            ProjectEditorView(project: project)
        }
    }
}

private struct TaskCapsuleRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    let task: FocusTask
    @State private var isEditing = false
    @State private var isShowingDetail = false
    @State private var isConfirmingDelete = false

    private var totalFocus: TimeInterval {
        dataStore.totalFocus(for: task.id)
    }

    private var canStart: Bool {
        store.phase == .idle
    }

    private var isCurrentTask: Bool {
        store.phase != .idle && store.currentTaskID == task.id
    }

    var body: some View {
        HStack(spacing: 13) {
            CategoryGlyph(
                category: task.category,
                symbol: dataStore.project(id: task.projectID)?.symbol
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(MossTypography.font(15, weight: .semibold))
                Text("\(task.timerActivity.title) · 已专注 \(totalFocus.compactDuration) · 完成 \(task.completedSessions) 段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Spacer()
            if task.estimatedSessions > 0 {
                Text("\(min(task.completedSessions, task.estimatedSessions))/\(task.estimatedSessions)")
                    .font(MossTypography.font(12, weight: .bold))
                    .foregroundStyle(MossTheme.sage)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MossTheme.sage.opacity(0.1), in: Capsule())
            }
            Menu {
                Button("按任务设置开始") { store.start(task: task) }
                    .disabled(!canStart)
                Button("先做 5 分钟") { store.start(task: task, mode: .ignition) }
                    .disabled(!canStart)
                Divider()
                Button("查看专注记录") { isShowingDetail = true }
                Button("编辑") { isEditing = true }
                    .disabled(isCurrentTask)
                Button("归档") {
                    dataStore.archiveTask(id: task.id, archived: true)
                }
                .disabled(isCurrentTask)
                Button("删除任务", role: .destructive) {
                    isConfirmingDelete = true
                }
                .disabled(isCurrentTask)
                if isCurrentTask {
                    Divider()
                    Text("请先结束当前专注")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("任务操作")
            Button {
                isShowingDetail = true
            } label: {
                Label("查看记录", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看记录")
            Button {
                store.start(task: task)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(MossTheme.sage, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canStart)
            .accessibilityLabel("开始 \(task.title)")
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $isEditing) {
            TaskEditorView(task: task)
        }
        .sheet(isPresented: $isShowingDetail) {
            TaskDetailView(task: task)
        }
        .confirmationDialog(
            "删除“\(task.title)”？",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("删除任务", role: .destructive) {
                dataStore.deleteTask(id: task.id)
            }
        } message: {
            Text("任务入口会删除，但过去的专注记录会永久保留在时间线和统计中。")
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
                        .buttonStyle(.plain)
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
        }
    }
}
