import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore

    private let task: FocusTask?
    @State private var title: String
    @State private var projectID: UUID?
    @State private var estimatedSessions: Int
    @State private var timerActivity: TimerActivity
    @State private var focusMinutes: Int
    @State private var breakMinutes: Int
    @State private var warmupSeconds: Int
    @State private var discardMinutes: Int

    init(task: FocusTask? = nil, projectID: UUID? = nil) {
        let defaults = FocusTaskDefaults.load()
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _projectID = State(initialValue: task?.projectID ?? projectID)
        _estimatedSessions = State(initialValue: task?.estimatedSessions ?? 1)
        _timerActivity = State(initialValue: task?.timerActivity ?? .pomodoro)
        _focusMinutes = State(initialValue: max(1, Int((task?.focusDuration ?? defaults.focusDuration) / 60)))
        _breakMinutes = State(initialValue: max(1, Int((task?.breakDuration ?? defaults.breakDuration) / 60)))
        _warmupSeconds = State(initialValue: Int(task?.warmupDuration ?? defaults.warmupDuration))
        _discardMinutes = State(initialValue: max(0, Int((task?.discardThreshold ?? defaults.discardThreshold) / 60)))
    }

    private var activeProjects: [FocusProject] {
        dataStore.projects.filter { !$0.archived }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task == nil ? "添加一个小任务" : "编辑任务")
                            .font(.title2.bold())
                        Text("计时方式跟随任务保存，以后随时可以修改。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("取消") { dismiss() }
                        .buttonStyle(MossJellyPlainButtonStyle())
                }

                editorField("任务名") {
                    TextField("例如：浮点数题目 3–5", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                editorField("所属项目 / 文件夹") {
                    Picker("所属项目", selection: $projectID) {
                        Text("未分类").tag(UUID?.none)
                        ForEach(activeProjects) { project in
                            Label(project.title, systemImage: project.symbol)
                                .tag(UUID?.some(project.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("计时活动").font(.caption.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(TimerActivity.allCases) { activity in
                            Button {
                                timerActivity = activity
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: activity.icon)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(timerActivity == activity ? .white : MossTheme.sage)
                                        .frame(width: 34, height: 34)
                                        .background(
                                            timerActivity == activity
                                                ? MossTheme.sage
                                                : MossTheme.sage.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(activity.title).font(MossTypography.font(13, weight: .semibold))
                                        Text(activity.subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                }
                                .padding(11)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(timerActivity == activity
                                              ? MossTheme.sage.opacity(0.11)
                                              : Color.primary.opacity(0.025))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(timerActivity == activity
                                                ? MossTheme.sage.opacity(0.55)
                                                : Color.primary.opacity(0.06))
                                )
                            }
                            .buttonStyle(MossJellyPlainButtonStyle())
                            .accessibilityLabel(activity.title)
                            .accessibilityValue(timerActivity == activity ? "已选择" : "未选择")
                            .accessibilityAddTraits(timerActivity == activity ? .isSelected : [])
                        }
                    }
                }

                if timerActivity != .infinite {
                    editorField(timerActivity == .stopwatch ? "参考目标" : "专注时长") {
                        Stepper("\(focusMinutes) 分钟", value: $focusMinutes, in: 1...240, step: 5)
                    }
                }

                if timerActivity == .pomodoro {
                    editorField("番茄休息") {
                        Stepper("\(breakMinutes) 分钟", value: $breakMinutes, in: 1...60)
                    }
                }

                editorField("进入状态时间") {
                    Picker("进入状态时间", selection: $warmupSeconds) {
                        Text("不等待").tag(0)
                        Text("30 秒").tag(30)
                        Text("1 分钟").tag(60)
                        Text("2 分钟").tag(120)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                editorField("误触保护") {
                    HStack {
                        Stepper("\(discardMinutes) 分钟内结束不计入", value: $discardMinutes, in: 0...10)
                        Spacer()
                        Text("历史记录不会生成")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                editorField("预估专注段") {
                    Picker("预估专注段", selection: $estimatedSessions) {
                        Text("自由专注").tag(0)
                        ForEach(1...8, id: \.self) { count in
                            Text("\(count) 段").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack {
                    Spacer()
                    Button(task == nil ? "添加任务" : "保存") {
                        save()
                    }
                    .buttonStyle(CapsuleButtonStyle(prominent: true))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(26)
        }
        .frame(width: 610, height: 720)
        .background(MossTheme.paper)
    }

    private func editorField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold))
            content()
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = dataStore.project(id: projectID)
        let category = project?.title ?? "未分类"
        if var task {
            task.title = cleanTitle
            task.projectID = projectID
            task.category = category
            task.estimatedSessions = estimatedSessions
            task.timerActivityRaw = timerActivity.rawValue
            task.focusDuration = timerActivity == .infinite ? 0 : TimeInterval(focusMinutes * 60)
            task.breakDuration = TimeInterval(breakMinutes * 60)
            task.warmupDuration = TimeInterval(warmupSeconds)
            task.discardThreshold = TimeInterval(discardMinutes * 60)
            dataStore.updateTask(task)
        } else {
            dataStore.addTask(FocusTask(
                projectID: projectID,
                title: cleanTitle,
                category: category,
                estimatedSessions: estimatedSessions,
                sortOrder: dataStore.tasks.count,
                timerActivity: timerActivity,
                focusDuration: timerActivity == .infinite ? 0 : TimeInterval(focusMinutes * 60),
                breakDuration: TimeInterval(breakMinutes * 60),
                warmupDuration: TimeInterval(warmupSeconds),
                discardThreshold: TimeInterval(discardMinutes * 60)
            ))
        }
        dismiss()
    }
}
