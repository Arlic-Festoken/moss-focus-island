import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var dataStore: DataStore

    private var archived: [FocusTask] {
        dataStore.tasks.filter(\.archived).sorted { $0.createdAt > $1.createdAt }
    }

    private var archivedProjects: [FocusProject] {
        dataStore.projects.filter(\.archived).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("归档")
                            .font(MossTypography.font(30, weight: .bold))
                        Text("完成的任务可以安静留在这里。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu("导出本地数据") {
                        Button("导出 JSON") {
                            try? ExportService.export(
                                projects: dataStore.projects,
                                tasks: dataStore.tasks,
                                sessions: dataStore.sessions,
                                format: .json
                            )
                        }
                        Button("导出 CSV") {
                            try? ExportService.export(
                                projects: dataStore.projects,
                                tasks: dataStore.tasks,
                                sessions: dataStore.sessions,
                                format: .csv
                            )
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                MossCard {
                    if archived.isEmpty && archivedProjects.isEmpty {
                        ContentUnavailableView(
                            "归档还是空的",
                            systemImage: "archivebox",
                            description: Text("在任务菜单中选择“归档”，它就会来到这里。")
                        )
                        .frame(minHeight: 260)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(archivedProjects) { project in
                                HStack {
                                    Image(systemName: project.symbol)
                                        .foregroundStyle(MossTheme.sage)
                                        .frame(width: 38, height: 38)
                                        .background(MossTheme.sage.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(project.title).font(.headline)
                                        Text("项目 · \(dataStore.totalFocus(forProjectID: project.id).compactDuration)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("恢复项目") {
                                        dataStore.archiveProject(id: project.id, archived: false)
                                    }
                                    .buttonStyle(CapsuleButtonStyle())
                                }
                                .padding(.vertical, 11)
                                Divider()
                            }
                            ForEach(archived) { task in
                                HStack {
                                    CategoryGlyph(category: task.category)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title).font(.headline)
                                        Text("\(task.category) · \(dataStore.totalFocus(for: task.id).compactDuration) · 完成 \(task.completedSessions) 段")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("恢复") {
                                        dataStore.archiveTask(id: task.id, archived: false)
                                    }
                                    .buttonStyle(CapsuleButtonStyle())
                                }
                                .padding(.vertical, 11)
                                if task.id != archived.last?.id { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }
}
