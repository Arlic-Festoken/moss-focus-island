import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore

    private let task: FocusTask?
    @State private var title: String
    @State private var category: String
    @State private var estimatedSessions: Int

    init(task: FocusTask? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _category = State(initialValue: task?.category ?? "计算机组成原理")
        _estimatedSessions = State(initialValue: task?.estimatedSessions ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task == nil ? "添加一个小任务" : "编辑任务")
                        .font(.title2.bold())
                    Text("边界越清楚，开始越轻。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("任务名").font(.caption.weight(.semibold))
                TextField("例如：浮点数题目 3–5", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("分类").font(.caption.weight(.semibold))
                TextField("例如：计算机组成原理", text: $category)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("预估专注段").font(.caption.weight(.semibold))
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
        .frame(width: 520)
        .background(MossTheme.paper)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if var task {
            task.title = cleanTitle
            task.category = cleanCategory.isEmpty ? "未分类" : cleanCategory
            task.estimatedSessions = estimatedSessions
            dataStore.updateTask(task)
        } else {
            dataStore.addTask(FocusTask(
                title: cleanTitle,
                category: cleanCategory.isEmpty ? "未分类" : cleanCategory,
                estimatedSessions: estimatedSessions,
                sortOrder: dataStore.tasks.count
            ))
        }
        dismiss()
    }
}
