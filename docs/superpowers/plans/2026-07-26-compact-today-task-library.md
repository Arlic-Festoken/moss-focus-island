# Compact Today Task Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Today’s full-width, unbounded task rows with a single-project accordion containing adaptive 2–3-column task tiles, progressive disclosure, and task-to-project drag and menu movement.

**Architecture:** Add a pure `TodayTaskPresentation` model for stable grouping, initial expansion, and six-item disclosure. Add one `DataStore.moveTask` mutation for both drag/drop and menu moves while preserving historical sessions. Extract Today’s task library into a focused SwiftUI file so `TodayView` remains responsible for page composition.

**Tech Stack:** Swift 6.2, SwiftUI on macOS 14, Swift Package Manager, existing shell behavior/UI regression checks.

---

### Task 1: Stable Today task presentation

**Files:**
- Create: `Sources/Moss/TodayTaskPresentation.swift`
- Modify: `Tests/MossBehaviorCheck.swift`

- [ ] **Step 1: Write the failing presentation test**

Add a behavior block before `preferred-start-task=pass`:

```swift
let presentationProject = FocusProject(
    id: UUID(),
    title: "学业主线",
    symbol: "graduationcap.fill",
    sortOrder: 0
)
let laterProject = FocusProject(
    id: UUID(),
    title: "创造实践",
    symbol: "hammer.fill",
    sortOrder: 1
)
let presentationTasks = (0..<8).map {
    FocusTask(
        projectID: presentationProject.id,
        title: "任务 \($0)",
        category: presentationProject.title,
        sortOrder: $0
    )
} + [
    FocusTask(
        title: "未分类任务",
        category: "未分类",
        sortOrder: 9
    )
]
let presentationGroups = TodayTaskPresentation.groups(
    projects: [laterProject, presentationProject],
    tasks: presentationTasks
)
precondition(presentationGroups.map(\.id) == [
    .project(presentationProject.id),
    .ungrouped
])
precondition(presentationGroups.last?.title == "未分类")
precondition(
    TodayTaskPresentation.defaultExpandedGroupID(
        groups: presentationGroups,
        preferredTaskID: presentationTasks[3].id
    ) == .project(presentationProject.id)
)
precondition(
    TodayTaskPresentation.visibleTasks(
        in: presentationGroups[0],
        showingAll: false
    ).count == 6
)
precondition(
    TodayTaskPresentation.remainingCount(
        in: presentationGroups[0],
        showingAll: false
    ) == 2
)
print("today-task-presentation=pass")
```

- [ ] **Step 2: Run the behavior check and verify RED**

Run:

```bash
./scripts/behavior-check.sh
```

Expected: compilation fails because `TodayTaskPresentation` does not exist.

- [ ] **Step 3: Implement the pure presentation model**

Create:

```swift
import Foundation

struct TodayTaskGroup: Identifiable, Hashable {
    enum ID: Hashable {
        case project(UUID)
        case ungrouped
    }

    let id: ID
    let project: FocusProject?
    let tasks: [FocusTask]

    var title: String { project?.title ?? "未分类" }
    var symbol: String { project?.symbol ?? "tray.fill" }
    var projectID: UUID? { project?.id }
}

enum TodayTaskPresentation {
    static let visibleLimit = 6

    static func groups(
        projects: [FocusProject],
        tasks: [FocusTask]
    ) -> [TodayTaskGroup] {
        let activeTasks = tasks
            .filter { !$0.archived }
            .sorted {
                if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
                return $0.sortOrder < $1.sortOrder
            }
        let activeProjects = projects
            .filter { !$0.archived }
            .sorted {
                if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
                return $0.sortOrder < $1.sortOrder
            }
        var result = activeProjects.compactMap { project -> TodayTaskGroup? in
            let projectTasks = activeTasks.filter { $0.projectID == project.id }
            guard !projectTasks.isEmpty else { return nil }
            return TodayTaskGroup(id: .project(project.id), project: project, tasks: projectTasks)
        }
        let ungrouped = activeTasks.filter { $0.projectID == nil }
        if !ungrouped.isEmpty {
            result.append(TodayTaskGroup(id: .ungrouped, project: nil, tasks: ungrouped))
        }
        return result
    }

    static func defaultExpandedGroupID(
        groups: [TodayTaskGroup],
        preferredTaskID: UUID?
    ) -> TodayTaskGroup.ID? {
        if let preferredTaskID,
           let group = groups.first(where: {
               $0.tasks.contains(where: { $0.id == preferredTaskID })
           }) {
            return group.id
        }
        return groups.first?.id
    }

    static func visibleTasks(
        in group: TodayTaskGroup,
        showingAll: Bool
    ) -> ArraySlice<FocusTask> {
        group.tasks.prefix(showingAll ? group.tasks.count : visibleLimit)
    }

    static func remainingCount(
        in group: TodayTaskGroup,
        showingAll: Bool
    ) -> Int {
        max(0, group.tasks.count - visibleTasks(in: group, showingAll: showingAll).count)
    }
}
```

- [ ] **Step 4: Run behavior tests and verify GREEN**

Run:

```bash
./scripts/behavior-check.sh
```

Expected: existing labels plus `today-task-presentation=pass`, exit 0.

- [ ] **Step 5: Commit the presentation model**

```bash
git add Sources/Moss/TodayTaskPresentation.swift Tests/MossBehaviorCheck.swift
git commit -m "feat: derive compact Today task groups"
```

### Task 2: Persistent task movement

**Files:**
- Modify: `Sources/Moss/DataStore.swift`
- Modify: `Tests/MossBehaviorCheck.swift`

- [ ] **Step 1: Write the failing task-movement test**

Add after the presentation test:

```swift
let movementDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("MossMoveTask-\(UUID().uuidString)", isDirectory: true)
try! FileManager.default.createDirectory(
    at: movementDirectory,
    withIntermediateDirectories: true
)
defer { try? FileManager.default.removeItem(at: movementDirectory) }
let movementURL = movementDirectory.appendingPathComponent("moss-data.json")
let movementStore = DataStore(fileURL: movementURL, seedIfMissing: false)
let sourceProject = FocusProject(title: "来源", sortOrder: 0)
let targetProject = FocusProject(title: "目标", sortOrder: 1)
movementStore.addProject(sourceProject)
movementStore.addProject(targetProject)
let targetExisting = FocusTask(
    projectID: targetProject.id,
    title: "已有",
    category: targetProject.title,
    sortOrder: 4
)
let movingTask = FocusTask(
    projectID: sourceProject.id,
    title: "待移动",
    category: sourceProject.title,
    sortOrder: 1
)
movementStore.addTask(targetExisting)
movementStore.addTask(movingTask)
let historicalSession = FocusSession(
    taskID: movingTask.id,
    taskTitle: movingTask.title,
    projectID: sourceProject.id,
    projectTitle: sourceProject.title,
    category: sourceProject.title,
    startedAt: .now,
    plannedDuration: 1_500,
    warmupDuration: 0,
    timerActivity: .pomodoro,
    mode: .standard
)
movementStore.addSession(historicalSession)
precondition(movementStore.moveTask(id: movingTask.id, toProjectID: targetProject.id))
precondition(movementStore.tasks.first(where: { $0.id == movingTask.id })?.projectID == targetProject.id)
precondition(movementStore.tasks.first(where: { $0.id == movingTask.id })?.category == targetProject.title)
precondition(movementStore.tasks.first(where: { $0.id == movingTask.id })?.sortOrder == 5)
precondition(movementStore.sessions.first?.projectID == sourceProject.id)
precondition(!movementStore.moveTask(id: movingTask.id, toProjectID: targetProject.id))
let reloadedMovementStore = DataStore(fileURL: movementURL, seedIfMissing: false)
precondition(reloadedMovementStore.tasks.first(where: { $0.id == movingTask.id })?.projectID == targetProject.id)
precondition(movementStore.moveTask(id: movingTask.id, toProjectID: sourceProject.id))
var archivedTarget = targetProject
archivedTarget.archived = true
movementStore.updateProject(archivedTarget)
precondition(!movementStore.moveTask(id: movingTask.id, toProjectID: archivedTarget.id))
precondition(movementStore.tasks.first(where: { $0.id == movingTask.id })?.projectID == sourceProject.id)
precondition(!movementStore.moveTask(id: movingTask.id, toProjectID: UUID()))
precondition(movementStore.moveTask(id: movingTask.id, toProjectID: nil))
precondition(movementStore.tasks.first(where: { $0.id == movingTask.id })?.category == "未分类")
print("task-project-movement=pass")
```

- [ ] **Step 2: Run the behavior check and verify RED**

Run:

```bash
./scripts/behavior-check.sh
```

Expected: compilation fails because `DataStore.moveTask` does not exist.

- [ ] **Step 3: Implement the single movement mutation**

Add after `updateTask`:

```swift
@discardableResult
func moveTask(id: UUID, toProjectID: UUID?) -> Bool {
    guard let taskIndex = tasks.firstIndex(where: { $0.id == id }) else { return false }
    guard tasks[taskIndex].projectID != toProjectID else { return false }

    let targetProject: FocusProject?
    if let toProjectID {
        guard let project = projects.first(where: { $0.id == toProjectID && !$0.archived }) else {
            return false
        }
        targetProject = project
    } else {
        targetProject = nil
    }

    let nextSortOrder = tasks
        .filter { $0.projectID == toProjectID && $0.id != id }
        .map(\.sortOrder)
        .max()
        .map { $0 + 1 } ?? 0
    tasks[taskIndex].projectID = toProjectID
    tasks[taskIndex].category = targetProject?.title ?? "未分类"
    tasks[taskIndex].sortOrder = nextSortOrder
    sortTasks()
    save()
    return true
}
```

- [ ] **Step 4: Run behavior tests and verify GREEN**

Run:

```bash
./scripts/behavior-check.sh
```

Expected: `task-project-movement=pass`, exit 0.

- [ ] **Step 5: Commit movement behavior**

```bash
git add Sources/Moss/DataStore.swift Tests/MossBehaviorCheck.swift
git commit -m "feat: move tasks between projects safely"
```

### Task 3: Compact accordion UI and drag/drop

**Files:**
- Create: `Sources/Moss/TodayTaskLibraryView.swift`
- Modify: `Sources/Moss/TodayView.swift`
- Modify: `scripts/ui-regression-check.sh`

- [ ] **Step 1: Write failing UI contracts**

Append:

```zsh
expect "Sources/Moss/TodayTaskPresentation.swift" "static let visibleLimit = 6"
expect "Sources/Moss/TodayTaskLibraryView.swift" "LazyVGrid"
expect "Sources/Moss/TodayTaskLibraryView.swift" "GridItem(.adaptive(minimum: 210, maximum: 270)"
expect "Sources/Moss/TodayTaskLibraryView.swift" ".draggable(task.id.uuidString)"
expect "Sources/Moss/TodayTaskLibraryView.swift" ".dropDestination(for: String.self)"
expect "Sources/Moss/TodayTaskLibraryView.swift" "Menu(\"移动到项目\")"
expect "Sources/Moss/TodayTaskLibraryView.swift" "展开另外"
reject "Sources/Moss/TodayView.swift" "ForEach(tasks) { task in"
reject "Sources/Moss/TodayView.swift" "private struct TaskCapsuleRow"
```

- [ ] **Step 2: Run UI contracts and verify RED**

Run:

```bash
./scripts/ui-regression-check.sh
```

Expected: missing `TodayTaskLibraryView.swift` contract, exit 1.

- [ ] **Step 3: Extract the task library and implement accordion state**

Create `TodayTaskLibraryView.swift` with:

```swift
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

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 270), spacing: 8, alignment: .top)
    ]

    var body: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if groups.isEmpty { emptyState } else { projectSections }
            }
        }
        .onAppear(perform: alignExpandedGroup)
        .onChange(of: groups.map(\.id)) { _, _ in alignExpandedGroup() }
        .onChange(of: store.currentTaskID) { _, _ in alignExpandedGroup(preferCurrent: true) }
    }
}
```

Implement helpers in the same file:

- `header` renders “今天的任务” and total count.
- `projectSections` renders all non-empty groups and passes one `isExpanded` flag.
- Tapping a project header sets `expandedGroupID`; opening one collapses the previous.
- `alignExpandedGroup(preferCurrent:)` keeps a valid selection and prefers the current or preferred task group.
- Expanded groups use `LazyVGrid(columns: columns)` and the presentation model’s six-task slice.
- “展开另外 N 项” toggles full visibility; “收起到 6 项” restores the limit.
- Empty state retains the existing copy and 160 pt height.

- [ ] **Step 4: Implement compact tiles and preserve actions**

Add `CompactTaskTile` in the new file:

```swift
private struct CompactTaskTile: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    let task: FocusTask
    let moveTargets: [TodayTaskGroup]
    let onMove: (FocusTask, TodayTaskGroup) -> Void

    private var canMove: Bool {
        !(store.phase != .idle && store.currentTaskID == task.id)
    }

    var body: some View {
        HStack(spacing: 8) {
            dragHandle
            detailButton
            taskMenu
            startButton
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 54)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(MossTheme.hairline, lineWidth: 1)
        }
        .help(task.title)
    }
}
```

Preserve the existing menu actions exactly: configured start, 5-minute start, records, edit, archive, delete, and the current-task guards. Add `Menu("移动到项目")` populated from `moveTargets`, excluding the task’s current group. The title area opens `TaskDetailView`; the 28 pt circular play button starts the task.

Add explicit accessibility labels to the drag handle:

```swift
.accessibilityLabel("拖动 \(task.title) 到其他项目")
.accessibilityHint(canMove ? "按住并拖到项目标题" : "请先结束当前专注")
```

The detail button reads the full task title and accumulated data, and the play button retains `开始 \(task.title)`.

- [ ] **Step 5: Implement project drop targets and feedback**

In each project section header:

```swift
.dropDestination(for: String.self) { items, _ in
    guard let rawID = items.first,
          let taskID = UUID(uuidString: rawID),
          let task = dataStore.tasks.first(where: { $0.id == taskID }) else {
        return false
    }
    return move(task, to: group)
} isTargeted: { isTargeted in
    targetedGroupID = isTargeted ? group.id : nil
}
```

On the handle, conditionally apply:

```swift
Image(systemName: "line.3.horizontal")
    .draggable(task.id.uuidString)
```

The shared move helper calls `dataStore.moveTask`, then:

```swift
store.showTransient("已将「\(task.title)」移到「\(group.title)」")
```

The project header uses sage border/background and “移到这里” while targeted. Do not auto-expand the destination after drop.
Use SwiftUI’s system drag preview without adding a custom movement animation, so the interaction automatically respects Reduce Motion.

- [ ] **Step 6: Replace Today’s old task section**

In `TodayView.taskCard`, replace the existing `MossCard` and all group iteration with:

```swift
TodayTaskLibraryView()
```

Delete `ProjectTaskSection` and `TaskCapsuleRow` from `TodayView.swift`. Keep `CategoryGlyph` because `ArchiveView` still uses it.

- [ ] **Step 7: Run UI, type, and behavior checks**

Run:

```bash
./scripts/ui-regression-check.sh
./scripts/typecheck.sh
./scripts/behavior-check.sh
```

Expected: UI contracts pass, typecheck exit 0, all behavior labels including the two new labels pass.

- [ ] **Step 8: Commit the compact UI**

```bash
git add Sources/Moss/TodayTaskLibraryView.swift Sources/Moss/TodayView.swift scripts/ui-regression-check.sh
git commit -m "feat: compact Today tasks into draggable groups"
```

### Task 4: Build and real-window verification

**Files:**
- Modify only if visual verification exposes a concrete defect.

- [ ] **Step 1: Run the complete verification suite**

Run:

```bash
./scripts/ui-regression-check.sh
./scripts/typecheck.sh
./scripts/behavior-check.sh
./scripts/build-app.sh
```

Expected: exit 0; behavior output includes 19 `=pass` labels; build prints the worktree `dist/Moss.app` path.

- [ ] **Step 2: Launch the isolated build**

Run:

```bash
open -n /Users/zhikanghuang/Developer/projects/moss-focus-island/.worktrees/compact-today-task-grid/dist/Moss.app
```

Use the real window to verify the user’s `学业主线` group at normal size:

- only one project is expanded;
- six visible tasks form 2–3 columns rather than full-width rows;
- “展开另外 7 项” is present for 13 tasks;
- the title, metrics, menu, and play button remain visually adjacent;
- collapsed project summaries remain visible.
- VoiceOver reads the full title, metrics, start action, drag handle, and menu movement.
- Light and dark appearances preserve contrast, and Reduce Motion introduces no custom drag animation.

- [ ] **Step 3: Verify interaction without corrupting user history**

Use menu movement or drag/drop on one inactive task, record its original project, move it to another project, verify both counts and the transient notice, then move it back. Confirm existing timeline records retain the old historical project. Do not move the active task.

- [ ] **Step 4: Run final post-QA verification**

Run:

```bash
git diff --check
./scripts/ui-regression-check.sh
./scripts/typecheck.sh
./scripts/behavior-check.sh
./scripts/build-app.sh
git status --short
```

Expected: all commands exit 0 and the worktree is clean after any required visual-fix commit.

- [ ] **Step 5: Finish the branch**

Invoke `superpowers:finishing-a-development-branch`, merge the verified branch into the user’s chosen base without including unrelated main-worktree changes, rerun the complete suite on the merged state, and leave the final app running.
