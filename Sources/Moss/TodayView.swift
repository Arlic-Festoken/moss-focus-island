import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @State private var isAddingTask = false

    private var activeTasks: [FocusTask] {
        dataStore.tasks.filter { !$0.archived }
    }

    private var metrics: DailyMetrics {
        InsightEngine.todayMetrics(
            sessions: dataStore.sessions,
            interruptions: dataStore.interruptions
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header
                statusCard

                HStack(alignment: .top, spacing: 18) {
                    taskCard
                        .frame(maxWidth: .infinity)
                    FocusWeatherCard(metrics: metrics)
                        .frame(width: 300)
                }

                HStack(alignment: .top, spacing: 18) {
                    TodayTimelineCard(sessions: dataStore.sessions)
                        .frame(maxWidth: .infinity)
                    DailyFeedbackCard(metrics: metrics)
                        .frame(width: 360)
                }
            }
            .padding(28)
            .frame(maxWidth: 1160, alignment: .leading)
        }
        .sheet(isPresented: $isAddingTask) {
            TaskEditorView()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(greeting)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isAddingTask = true
            } label: {
                Label("新任务", systemImage: "plus")
            }
            .buttonStyle(CapsuleButtonStyle())
        }
    }

    private var statusCard: some View {
        MossCard {
            HStack(spacing: 26) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(store.isActive ? "此刻正在专注" : "今天已经专注")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MossTheme.sage)
                    Text(store.isActive ? store.remaining.clockString : metrics.totalFocus.compactDuration)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(store.isActive
                         ? "\(store.currentCategory) · \(store.currentTaskTitle)"
                         : "完成 \(metrics.completedCount) 个专注段")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isActive {
                    ProgressRing(
                        progress: store.progress,
                        lineWidth: 9,
                        tint: store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage
                    )
                    .frame(width: 94, height: 94)
                    .overlay {
                        Image(systemName: store.phase == .paused ? "pause.fill" : store.phase == .breakTime ? "cup.and.saucer.fill" : "leaf.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 10) {
                        if let next = activeTasks.first {
                            Text("下一任务")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(next.title)
                                .font(.headline)
                            HStack {
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
            }
        }
    }

    private var taskCard: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("今天的任务")
                        .font(.title3.bold())
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
                    ForEach(activeTasks) { task in
                        TaskCapsuleRow(task: task)
                            .environmentObject(store)
                        if task.id != activeTasks.last?.id {
                            Divider().opacity(0.55)
                        }
                    }
                }
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

private struct TaskCapsuleRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    let task: FocusTask
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 13) {
            CategoryGlyph(category: task.category)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(task.category) · \(task.estimatedSessions == 0 ? "自由专注" : "预计 \(task.estimatedSessions) 段") · 已完成 \(task.completedSessions) 段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            Spacer()
            if task.estimatedSessions > 0 {
                Text("\(min(task.completedSessions, task.estimatedSessions))/\(task.estimatedSessions)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(MossTheme.sage)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MossTheme.sage.opacity(0.1), in: Capsule())
            }
            Menu {
                Button("开始 25 分钟") { store.start(task: task) }
                Button("先做 5 分钟") { store.start(task: task, mode: .ignition) }
                Divider()
                Button("编辑") { isEditing = true }
                Button("归档") {
                    dataStore.archiveTask(id: task.id, archived: true)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            Button {
                store.start(task: task, mode: task.estimatedSessions == 0 ? .free : .standard)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(MossTheme.sage, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(store.phase != .idle)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            store.start(task: task)
        }
        .sheet(isPresented: $isEditing) {
            TaskEditorView(task: task)
        }
    }
}

struct CategoryGlyph: View {
    let category: String

    var symbol: String {
        if category.contains("英语") { return "text.bubble.fill" }
        if category.contains("项目") || category.contains("开发") { return "point.3.connected.trianglepath.dotted" }
        if category.contains("阅读") { return "book.closed.fill" }
        if category.contains("健身") || category.contains("跑步") { return "figure.run" }
        return "leaf.fill"
    }

    var body: some View {
        Image(systemName: symbol)
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
        MossCard {
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
                    .font(.title3.bold())
                Text(weather.advice)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TodayTimelineCard: View {
    let sessions: [FocusSession]

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
                        .font(.title3.bold())
                    Spacer()
                    NavigationLink("查看全部") {
                        TimelinePage()
                    }
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
                .font(.system(size: 12, design: .monospaced))
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
                    .font(.system(size: 13, weight: .semibold))
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
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(MossTheme.sage)
                    Text("今日反馈")
                        .font(.title3.bold())
                }
                ForEach(Array(InsightEngine.feedback(for: metrics).enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(MossTheme.sage)
                            .frame(width: 22, height: 22)
                            .background(MossTheme.sage.opacity(0.1), in: Circle())
                        Text(item)
                            .font(.system(size: 13))
                            .foregroundStyle(index == 2 ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
