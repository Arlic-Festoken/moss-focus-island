import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("breakMinutes") private var breakMinutes = 5
    @AppStorage("showNotchIsland") private var showNotchIsland = true
    @AppStorage("subtleSound") private var subtleSound = true
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue

    var body: some View {
        ScrollView {
            Form {
                Section("外观主题") {
                    ThemePicker(selection: $colorTheme)
                        .padding(.vertical, 6)
                    Text("主题会同步改变主色、完成色、休息色与纸张背景。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("计时") {
                    Stepper("标准专注：\(focusMinutes) 分钟", value: $focusMinutes, in: 5...90, step: 5)
                    Stepper("休息：\(breakMinutes) 分钟", value: $breakMinutes, in: 1...30)
                }
                Section("专注岛") {
                    Toggle("显示顶部专注岛", isOn: $showNotchIsland)
                        .onChange(of: showNotchIsland) { _, newValue in
                            newValue
                                ? NotchPanelController.shared.show(store: store)
                                : NotchPanelController.shared.hide()
                        }
                    Toggle("完成时播放轻提示音", isOn: $subtleSound)
                }
                Section("隐私与数据") {
                    LabeledContent("网络请求", value: "0")
                    LabeledContent("数据位置", value: "仅存储在这台 Mac")
                    HStack {
                        Button("导出 JSON") {
                            try? ExportService.export(tasks: dataStore.tasks, sessions: dataStore.sessions, format: .json)
                        }
                        Button("导出 CSV") {
                            try? ExportService.export(tasks: dataStore.tasks, sessions: dataStore.sessions, format: .csv)
                        }
                    }
                }
                Section("快捷操作") {
                    LabeledContent("开始上一次任务", value: "⌘ ⇧ F")
                    LabeledContent("暂停 / 继续", value: "⌘ ⇧ P")
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .frame(maxWidth: 720)
        }
        .background(MossTheme.paper)
    }
}

private struct ThemePicker: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(MossColorTheme.allCases) { theme in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selection = theme.rawValue
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 5) {
                            ForEach(1...4, id: \.self) { level in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.accent.opacity(0.18 + Double(level) * 0.20))
                                    .frame(width: 23, height: 23)
                            }
                            Spacer()
                            if selection == theme.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        Text(theme.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(theme.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(selection == theme.rawValue
                                  ? theme.accent.opacity(0.13)
                                  : Color.primary.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(
                                selection == theme.rawValue
                                    ? theme.accent.opacity(0.65)
                                    : Color.primary.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
