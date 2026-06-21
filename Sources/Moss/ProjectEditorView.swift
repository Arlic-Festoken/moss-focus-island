import SwiftUI

struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore

    private let project: FocusProject?
    @State private var title: String
    @State private var symbol: String

    private let symbols = [
        "folder.fill", "book.closed.fill", "cpu.fill", "text.bubble.fill",
        "hammer.fill", "leaf.fill", "figure.run", "paintbrush.fill",
        "music.note", "globe", "graduationcap.fill", "lightbulb.fill"
    ]

    init(project: FocusProject? = nil) {
        self.project = project
        _title = State(initialValue: project?.title ?? "")
        _symbol = State(initialValue: project?.symbol ?? "folder.fill")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project == nil ? "新建项目 / 文件夹" : "编辑项目")
                        .font(.title2.bold())
                    Text("把一组相关的小任务放在一起。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(.plain)
            }

            TextField("项目名称", text: $title)
                .textFieldStyle(.roundedBorder)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(symbols, id: \.self) { item in
                    Button {
                        symbol = item
                    } label: {
                        Image(systemName: item)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(symbol == item ? .white : MossTheme.sage)
                            .frame(width: 48, height: 44)
                            .background(
                                symbol == item ? MossTheme.sage : MossTheme.sage.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button(project == nil ? "创建项目" : "保存") {
                    save()
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(26)
        .frame(width: 470)
        .background(MossTheme.paper)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if var project {
            project.title = cleanTitle
            project.symbol = symbol
            dataStore.updateProject(project)
        } else {
            dataStore.addProject(FocusProject(
                title: cleanTitle,
                symbol: symbol,
                sortOrder: dataStore.projects.count
            ))
        }
        dismiss()
    }
}
