import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("breakMinutes") private var breakMinutes = 5
    @AppStorage("showNotchIsland") private var showNotchIsland = true
    @AppStorage("subtleSound") private var subtleSound = true
    @AppStorage("launchSilently") private var launchSilently = true
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue
    @AppStorage("fontTheme") private var fontTheme = MossFontTheme.rounded.rawValue
    @AppStorage("fontSize") private var fontSize = MossFontSize.standard.rawValue
    @AppStorage("islandPlacement") private var islandPlacement = IslandPlacement.topCenter.rawValue
    @AppStorage("islandOffsetX") private var islandOffsetX = 0.0
    @AppStorage("islandOffsetY") private var islandOffsetY = 0.0

    var body: some View {
        ScrollView {
            Form {
                Section("启动") {
                    Toggle("启动后仅在菜单栏驻留", isOn: $launchSilently)
                    Text("下次启动时生效。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("外观主题") {
                    ThemePicker(selection: $colorTheme)
                        .padding(.vertical, 6)
                    Text("主题会同步改变主色、完成色、休息色与纸张背景。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("字体") {
                    FontThemePicker(selection: $fontTheme)
                    Picker("界面字号", selection: $fontSize) {
                        ForEach(MossFontSize.allCases) { size in
                            Text(size.title).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Moss 专注岛 · \(MossFontTheme(rawValue: fontTheme)?.title ?? "圆体")")
                        .font((MossFontTheme(rawValue: fontTheme) ?? .rounded).font(
                            size: 17 * (MossFontSize(rawValue: fontSize) ?? .standard).scale,
                            weight: .semibold
                        ))
                        .foregroundStyle(MossTheme.sage)
                        .padding(.vertical, 4)
                }
                Section("计时") {
                    Stepper("新任务默认专注：\(focusMinutes) 分钟", value: $focusMinutes, in: 5...90, step: 5)
                    Stepper("新任务默认休息：\(breakMinutes) 分钟", value: $breakMinutes, in: 1...30)
                    Text("只影响之后创建的任务；已有任务仍使用各自保存的设置。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("专注岛") {
                    Toggle("显示顶部专注岛", isOn: $showNotchIsland)
                        .onChange(of: showNotchIsland) { _, newValue in
                            newValue
                                ? NotchPanelController.shared.show(store: store)
                                : NotchPanelController.shared.hide()
                        }
                    Toggle("完成时播放轻提示音", isOn: $subtleSound)
                    IslandPlacementPicker(selection: $islandPlacement)
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("水平微调")
                            Slider(value: $islandOffsetX, in: -220...220, step: 2)
                            Text("\(Int(islandOffsetX))")
                                .font(.caption.monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                        }
                        HStack {
                            Text("垂直微调")
                            Slider(value: $islandOffsetY, in: -140...140, step: 2)
                            Text("\(Int(islandOffsetY))")
                                .font(.caption.monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                        }
                        HStack {
                            Text("可以在预设位置基础上继续微调，也可以直接拖动专注岛。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("重置位置") {
                                islandPlacement = IslandPlacement.topCenter.rawValue
                                islandOffsetX = 0
                                islandOffsetY = 0
                                NotchPanelController.shared.reposition()
                            }
                        }
                    }
                    .onChange(of: islandPlacement) { _, _ in NotchPanelController.shared.reposition() }
                    .onChange(of: islandOffsetX) { _, _ in NotchPanelController.shared.reposition() }
                    .onChange(of: islandOffsetY) { _, _ in NotchPanelController.shared.reposition() }
                }
                Section("隐私与数据") {
                    LabeledContent("网络请求", value: "0")
                    LabeledContent("数据位置", value: "仅存储在这台 Mac")
                    HStack {
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
                }
                Section("快捷操作") {
                    LabeledContent("开始上一次任务", value: "⌘ ⇧ F")
                    LabeledContent("暂停 / 继续", value: "⌘ ⇧ P")
                    LabeledContent("结束 / 取消开始", value: "⌘ ⇧ E")
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .frame(maxWidth: 720)
        }
        .background(MossTheme.paper)
    }
}

private struct IslandPlacementPicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("显示位置").font(.caption.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(IslandPlacement.allCases) { placement in
                    Button {
                        selection = placement.rawValue
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: placement.icon)
                                .font(.system(size: 15, weight: .semibold))
                            Text(placement.title)
                                .font(.caption2)
                        }
                        .foregroundStyle(selection == placement.rawValue ? MossTheme.current.accentForeground : MossTheme.sage)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selection == placement.rawValue
                                ? MossTheme.sage
                                : MossTheme.sage.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(placement.title)
                    .accessibilityValue(selection == placement.rawValue ? "已选择" : "未选择")
                    .accessibilityAddTraits(selection == placement.rawValue ? .isSelected : [])
                }
            }
        }
    }
}

private struct FontThemePicker: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 125, maximum: 170), spacing: 9)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
            ForEach(MossFontTheme.allCases) { theme in
                Button {
                    selection = theme.rawValue
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Aa 字")
                                .font(theme.font(size: 18, weight: .semibold))
                            Spacer()
                            if selection == theme.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(MossTheme.sage)
                            }
                        }
                        Text(theme.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selection == theme.rawValue
                            ? MossTheme.sage.opacity(0.10)
                            : Color.primary.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 13)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(selection == theme.rawValue
                                    ? MossTheme.sage.opacity(0.5)
                                    : Color.primary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.title)
                .accessibilityValue(selection == theme.rawValue ? "已选择" : "未选择")
                .accessibilityAddTraits(selection == theme.rawValue ? .isSelected : [])
            }
        }
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
                            .font(MossTypography.font(13, weight: .semibold))
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
                .accessibilityLabel(theme.title)
                .accessibilityValue(selection == theme.rawValue ? "已选择" : "未选择")
                .accessibilityAddTraits(selection == theme.rawValue ? .isSelected : [])
            }
        }
    }
}
