import SwiftUI

struct TodayTaskLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @State private var expandedGroupID: TodayTaskGroup.ID?
    @State private var showingAllGroupIDs: Set<TodayTaskGroup.ID> = []
    @State private var targetedGroupID: TodayTaskGroup.ID?

    private var groups: [TodayTaskGroup] {
        TodayTaskPresentation.groups(
            projects: dataStore.projects,
            tasks: dataStore.startableTasks
        )
    }

    var body: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("今天的任务")
                        .font(MossTypography.editorial(20, weight: .semibold))
                    Spacer()
                    Text("\(dataStore.startableTasks.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if groups.isEmpty {
                    ContentUnavailableView(
                        "今天还很清爽",
                        systemImage: "leaf",
                        description: Text("添加一个边界清楚的小任务。")
                    )
                    .frame(height: 160)
                } else {
                    VStack(spacing: 9) {
                        ForEach(groups) { group in
                            ProjectTaskSection(
                                group: group,
                                moveTargets: groups,
                                isExpanded: expandedGroupID == group.id,
                                isShowingAll: showingAllGroupIDs.contains(group.id),
                                isDropTargeted: targetedGroupID == group.id,
                                onToggle: { toggle(group) },
                                onToggleShowingAll: { toggleShowingAll(group) },
                                onDropTargeted: { setTargeted($0, group: group) },
                                onMove: move
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            alignExpandedGroup()
        }
        .onChange(of: groups.map(\.id)) { _, _ in
            alignExpandedGroup()
        }
        .onChange(of: store.currentTaskID) { _, _ in
            alignExpandedGroup(preferCurrent: true)
        }
    }

    private func toggle(_ group: TodayTaskGroup) {
        withAnimation(.easeOut(duration: 0.18)) {
            expandedGroupID = expandedGroupID == group.id ? nil : group.id
        }
    }

    private func toggleShowingAll(_ group: TodayTaskGroup) {
        withAnimation(.easeOut(duration: 0.18)) {
            if showingAllGroupIDs.contains(group.id) {
                showingAllGroupIDs.remove(group.id)
            } else {
                showingAllGroupIDs.insert(group.id)
            }
        }
    }

    private func setTargeted(_ isTargeted: Bool, group: TodayTaskGroup) {
        if isTargeted {
            targetedGroupID = group.id
        } else if targetedGroupID == group.id {
            targetedGroupID = nil
        }
    }

    private func move(_ task: FocusTask, to group: TodayTaskGroup) -> Bool {
        guard !(store.phase != .idle && store.currentTaskID == task.id) else {
            return false
        }
        guard dataStore.moveTask(id: task.id, toProjectID: group.projectID) else {
            return false
        }
        store.showTransient("已将「\(task.title)」移到「\(group.title)」")
        return true
    }

    private func alignExpandedGroup(preferCurrent: Bool = false) {
        guard !groups.isEmpty else {
            expandedGroupID = nil
            return
        }

        if preferCurrent,
           let currentTaskID = store.currentTaskID,
           let currentGroup = groups.first(where: {
               $0.tasks.contains(where: { $0.id == currentTaskID })
           }) {
            expandedGroupID = currentGroup.id
            return
        }

        if let expandedGroupID,
           groups.contains(where: { $0.id == expandedGroupID }) {
            return
        }

        let preferredTaskID = store.phase == .idle
            ? dataStore.preferredStartTask?.id
            : store.currentTaskID
        expandedGroupID = TodayTaskPresentation.defaultExpandedGroupID(
            groups: groups,
            preferredTaskID: preferredTaskID
        )
    }
}

private struct ProjectTaskSection: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore

    let group: TodayTaskGroup
    let moveTargets: [TodayTaskGroup]
    let isExpanded: Bool
    let isShowingAll: Bool
    let isDropTargeted: Bool
    let onToggle: () -> Void
    let onToggleShowingAll: () -> Void
    let onDropTargeted: (Bool) -> Void
    let onMove: (FocusTask, TodayTaskGroup) -> Bool

    @State private var isAddingTask = false
    @State private var isEditingProject = false

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 270), spacing: 8, alignment: .top)
    ]

    private var totalFocus: TimeInterval {
        if let projectID = group.projectID {
            return dataStore.totalFocus(forProjectID: projectID)
        }
        return group.tasks.reduce(0) { $0 + dataStore.totalFocus(for: $1.id) }
    }

    private var containsCurrentTask: Bool {
        store.phase != .idle
            && group.tasks.contains(where: { $0.id == store.currentTaskID })
    }

    private var visibleTasks: ArraySlice<FocusTask> {
        TodayTaskPresentation.visibleTasks(in: group, showingAll: isShowingAll)
    }

    private var remainingCount: Int {
        TodayTaskPresentation.remainingCount(in: group, showingAll: isShowingAll)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader

            if isExpanded {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(visibleTasks) { task in
                        CompactTaskTile(
                            task: task,
                            moveTargets: moveTargets,
                            onMove: onMove
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, group.tasks.count > TodayTaskPresentation.visibleLimit ? 8 : 12)

                if group.tasks.count > TodayTaskPresentation.visibleLimit {
                    Button(action: onToggleShowingAll) {
                        HStack(spacing: 7) {
                            Text(
                                isShowingAll
                                    ? "收起到 \(TodayTaskPresentation.visibleLimit) 项"
                                    : "展开另外 \(remainingCount) 项"
                            )
                            Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(MossTypography.font(10, weight: .semibold))
                        .foregroundStyle(MossTheme.sage)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(MossTheme.sage.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(
            isDropTargeted ? MossTheme.sage.opacity(0.105) : MossTheme.quietFill,
            in: RoundedRectangle(cornerRadius: 15)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    isDropTargeted ? MossTheme.sage.opacity(0.72) : MossTheme.hairline,
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        }
        .sheet(isPresented: $isAddingTask) {
            TaskEditorView(projectID: group.projectID)
        }
        .sheet(isPresented: $isEditingProject) {
            if let project = group.project {
                ProjectEditorView(project: project)
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: group.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MossTheme.sage)
                        .frame(width: 32, height: 32)
                        .background(
                            MossTheme.sage.opacity(0.105),
                            in: RoundedRectangle(cornerRadius: 10)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(MossTypography.font(13, weight: .bold))
                        Text("\(group.tasks.count) 个任务 · \(totalFocus.compactDuration)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    if isDropTargeted {
                        Text("移到这里")
                            .font(MossTypography.font(9, weight: .bold))
                            .foregroundStyle(MossTheme.sage)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                isAddingTask = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("在\(group.title)中添加任务")

            if let project = group.project {
                Menu {
                    Button("编辑项目") {
                        isEditingProject = true
                    }
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
                        .frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("\(group.title)项目操作")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .dropDestination(for: String.self) { items, _ in
            guard let rawID = items.first,
                  let taskID = UUID(uuidString: rawID),
                  let task = dataStore.tasks.first(where: { $0.id == taskID }) else {
                return false
            }
            return onMove(task, group)
        } isTargeted: { isTargeted in
            onDropTargeted(isTargeted)
        }
    }
}

private struct CompactTaskTile: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore

    let task: FocusTask
    let moveTargets: [TodayTaskGroup]
    let onMove: (FocusTask, TodayTaskGroup) -> Bool

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

    private var canMove: Bool {
        !isCurrentTask
    }

    private var availableMoveTargets: [TodayTaskGroup] {
        moveTargets.filter { $0.projectID != task.projectID }
    }

    var body: some View {
        HStack(spacing: 7) {
            dragHandle
            detailButton
            taskMenu
            startButton
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: 270, minHeight: 56)
        .background(MossTheme.card.opacity(0.58), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(MossTheme.hairline, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .help(task.title)
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

    @ViewBuilder
    private var dragHandle: some View {
        if canMove {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 13, height: 28)
                .contentShape(Rectangle())
                .draggable(task.id.uuidString)
                .accessibilityLabel("拖动 \(task.title) 到其他项目")
                .accessibilityHint("按住并拖到项目标题")
        } else {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.quaternary)
                .frame(width: 13, height: 28)
                .accessibilityLabel("拖动 \(task.title) 到其他项目")
                .accessibilityHint("请先结束当前专注")
        }
    }

    private var detailButton: some View {
        Button {
            isShowingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(MossTypography.font(12, weight: .semibold))
                    .lineLimit(1)
                Text("\(totalFocus.compactDuration) · \(task.completedSessions) 段")
                    .font(MossTypography.font(8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(task.title)，已专注 \(totalFocus.chineseDuration)，完成 \(task.completedSessions) 段"
        )
        .accessibilityHint("打开任务记录")
    }

    private var taskMenu: some View {
        Menu {
            Button("按任务设置开始") {
                store.start(task: task)
            }
            .disabled(!canStart)
            Button("先做 5 分钟") {
                store.start(task: task, mode: .ignition)
            }
            .disabled(!canStart)

            if !availableMoveTargets.isEmpty {
                Divider()
                Menu("移动到项目") {
                    ForEach(availableMoveTargets) { target in
                        Button(target.title) {
                            _ = onMove(task, target)
                        }
                    }
                }
                .disabled(!canMove)
            }

            Divider()
            Button("查看专注记录") {
                isShowingDetail = true
            }
            Button("编辑") {
                isEditing = true
            }
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
                .font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 28)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("\(task.title)任务操作")
    }

    private var startButton: some View {
        Button {
            store.start(task: task)
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(MossTheme.sage, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .accessibilityLabel("开始 \(task.title)")
    }
}
