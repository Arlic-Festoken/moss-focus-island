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
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            }
        let activeProjects = projects
            .filter { !$0.archived }
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortOrder < $1.sortOrder
            }

        var result = activeProjects.compactMap { project -> TodayTaskGroup? in
            let projectTasks = activeTasks.filter { $0.projectID == project.id }
            guard !projectTasks.isEmpty else { return nil }
            return TodayTaskGroup(
                id: .project(project.id),
                project: project,
                tasks: projectTasks
            )
        }

        let ungrouped = activeTasks.filter { $0.projectID == nil }
        if !ungrouped.isEmpty {
            result.append(
                TodayTaskGroup(id: .ungrouped, project: nil, tasks: ungrouped)
            )
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
        max(
            0,
            group.tasks.count
                - visibleTasks(in: group, showingAll: showingAll).count
        )
    }
}
