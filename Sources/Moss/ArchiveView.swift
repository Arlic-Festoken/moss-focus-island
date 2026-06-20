import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var dataStore: DataStore

    private var archived: [FocusTask] {
        dataStore.tasks.filter(\.archived).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("归档")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("完成的任务可以安静留在这里。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu("导出本地数据") {
                        Button("导出 JSON") {
                            try? ExportService.export(tasks: dataStore.tasks, sessions: dataStore.sessions, format: .json)
                        }
                        Button("导出 CSV") {
                            try? ExportService.export(tasks: dataStore.tasks, sessions: dataStore.sessions, format: .csv)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                MossCard {
                    if archived.isEmpty {
                        ContentUnavailableView(
                            "归档还是空的",
                            systemImage: "archivebox",
                            description: Text("在任务菜单中选择“归档”，它就会来到这里。")
                        )
                        .frame(minHeight: 260)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(archived) { task in
                                HStack {
                                    CategoryGlyph(category: task.category)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(task.title).font(.headline)
                                        Text("\(task.category) · 完成 \(task.completedSessions) 段")
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
