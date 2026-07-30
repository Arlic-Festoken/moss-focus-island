import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject private var cloudSync: CloudSyncController
    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("breakMinutes") private var breakMinutes = 5
    @AppStorage("showNotchIsland") private var showNotchIsland = true
    @AppStorage("showDesktopWidget") private var showDesktopWidget = false
    @AppStorage("subtleSound") private var subtleSound = true
    @AppStorage("launchSilently") private var launchSilently = true
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue
    @AppStorage("fontTheme") private var fontTheme = MossFontTheme.rounded.rawValue
    @AppStorage("fontSize") private var fontSize = MossFontSize.standard.rawValue
    @AppStorage("islandPlacement") private var islandPlacement = IslandPlacement.topCenter.rawValue
    @AppStorage("islandOffsetX") private var islandOffsetX = 0.0
    @AppStorage("islandOffsetY") private var islandOffsetY = 0.0
    @AppStorage("backgroundImageEnabled") private var backgroundImageEnabled = false
    @AppStorage("backgroundImageFileName") private var backgroundImageFileName = ""
    @AppStorage("backgroundBlurRadius") private var backgroundBlurRadius = 24.0
    @AppStorage("backgroundImageOpacity") private var backgroundImageOpacity = 0.34
    @AppStorage("growthTheme") private var growthTheme = GrowthTheme.douluo.rawValue
    @AppStorage("douluoAvatarForm") private var douluoAvatarForm = DouluoAvatarForm.soulMaster.rawValue
    @State private var exportFeedback: String?
    @State private var backgroundFeedback: String?
    @State private var isChoosingBackgroundImage = false

    var body: some View {
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
            Section("自定义背景") {
                BackgroundImagePreview(
                    fileName: backgroundImageFileName,
                    blurRadius: backgroundBlurRadius,
                    imageOpacity: backgroundImageOpacity
                )
                .frame(height: 132)

                Toggle("启用图片背景", isOn: $backgroundImageEnabled)
                    .disabled(backgroundImageFileName.isEmpty)

                HStack {
                    Button(backgroundImageFileName.isEmpty ? "导入图片" : "更换图片") {
                        isChoosingBackgroundImage = true
                    }
                    .buttonStyle(CapsuleButtonStyle(prominent: backgroundImageFileName.isEmpty))

                    if !backgroundImageFileName.isEmpty {
                        Button("移除背景", role: .destructive) {
                            BackgroundImageStore.removeImage(fileName: backgroundImageFileName)
                            backgroundImageFileName = ""
                            backgroundImageEnabled = false
                            backgroundFeedback = "自定义背景已移除。"
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("虚化程度")
                        Slider(value: $backgroundBlurRadius, in: 0...60)
                        Text("\(Int(backgroundBlurRadius))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 30, alignment: .trailing)
                    }
                    HStack {
                        Text("图片可见度")
                        Slider(value: $backgroundImageOpacity, in: 0.08...0.72)
                        Text("\(Int((backgroundImageOpacity * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                .disabled(backgroundImageFileName.isEmpty)

                Text(backgroundFeedback ?? "图片只会复制到 Moss 的本地数据目录，不会上传。")
                    .font(.caption)
                    .foregroundStyle(backgroundFeedback == nil ? .secondary : MossTheme.sage)
            }
            Section("成长主题") {
                GrowthThemePicker(selection: $growthTheme)
                if growthTheme == GrowthTheme.douluo.rawValue {
                    Picker("斗罗形态", selection: $douluoAvatarForm) {
                        ForEach(DouluoAvatarForm.allCases) { form in
                            Label(form.title, systemImage: form.symbol)
                                .tag(form.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Text("桌宠已经移入侧边栏的独立板块。主题只改变叙事和等级展示，不会修改任何专注记录。")
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
            Section("悬浮专注岛") {
                Toggle("显示悬浮专注岛", isOn: $showNotchIsland)
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
                        Slider(value: $islandOffsetX, in: -2_000...2_000)
                        Text("\(Int(islandOffsetX))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 38, alignment: .trailing)
                    }
                    HStack {
                        Text("垂直微调")
                        Slider(value: $islandOffsetY, in: -1_200...1_200)
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
                            NotchPanelController.shared.resetPosition()
                        }
                    }
                }
                .onChange(of: islandPlacement) { _, _ in
                    islandOffsetX = 0
                    islandOffsetY = 0
                    UserDefaults.standard.removeObject(forKey: "islandDisplayID")
                    NotchPanelController.shared.resetPosition()
                }
                .onChange(of: islandOffsetX) { _, _ in
                    NotchPanelController.shared.reposition(animated: false)
                }
                .onChange(of: islandOffsetY) { _, _ in
                    NotchPanelController.shared.reposition(animated: false)
                }
            }
            Section("桌面小组件") {
                Toggle("显示桌面专注小组件", isOn: $showDesktopWidget)
                    .onChange(of: showDesktopWidget) { _, newValue in
                        DesktopWidgetPanelController.shared.setVisible(
                            newValue,
                            store: store,
                            dataStore: dataStore
                        )
                    }
                Text("小组件停在桌面层，不会盖住普通应用窗口；可以拖动，并会记住位置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("可直接选择任务、开始 5 分钟点火，并控制暂停、继续和结束。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("重置位置") {
                        DesktopWidgetPanelController.shared.resetPosition()
                    }
                }
            }
            Section("iCloud 同步") {
                Toggle(
                    "在 Mac、iPhone 和 iPad 间同步",
                    isOn: Binding(
                        get: { cloudSync.isEnabled },
                        set: { cloudSync.setEnabled($0) }
                    )
                )

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cloudSync.status.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            cloudSync.status == .disabled
                                ? Color.secondary
                                : MossTheme.sage
                        )
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudSync.status.title)
                            .font(MossTypography.font(13, weight: .semibold))
                        Text(cloudSync.status.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("立即同步") {
                        cloudSync.syncNow()
                    }
                    .disabled(
                        !cloudSync.isEnabled
                            || cloudSync.status == .checking
                            || cloudSync.status == .syncing
                    )
                }
                .padding(.vertical, 4)

                Text("使用你的 CloudKit 私有数据库。Moss 始终先保存到本地；断网、退出 iCloud 或同步失败都不会删除本机数据。需要所有设备登录同一个 Apple ID。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("隐私与数据") {
                if let issue = dataStore.storageIssue {
                    VStack(alignment: .leading, spacing: 7) {
                        Label(issue.title, systemImage: issue.kind == .recovered ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                            .font(.headline)
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            if issue.canRestoreBackup {
                                Button("从备份恢复") {
                                    dataStore.restoreBackup()
                                }
                            }
                            Button("关闭提示") {
                                dataStore.dismissStorageIssue()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                LabeledContent(
                    "网络请求",
                    value: cloudSync.isEnabled ? "仅 Apple CloudKit" : "0"
                )
                LabeledContent(
                    "数据位置",
                    value: cloudSync.isEnabled ? "本机 + iCloud 私有数据库" : "仅存储在这台 Mac"
                )
                HStack {
                    Button("导出 JSON") {
                        exportData(.json)
                    }
                    Button("导出 CSV") {
                        exportData(.csv)
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
        .scrollContentBackground(.hidden)
        .padding(20)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(
            MossTheme.paper.opacity(
                backgroundImageEnabled && !backgroundImageFileName.isEmpty ? 0.78 : 1
            )
        )
        .fileImporter(
            isPresented: $isChoosingBackgroundImage,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            importBackgroundImage(result)
        }
        .alert(
            "本地导出",
            isPresented: Binding(
                get: { exportFeedback != nil },
                set: { if !$0 { exportFeedback = nil } }
            )
        ) {
            Button("知道了") { exportFeedback = nil }
        } message: {
            Text(exportFeedback ?? "")
        }
    }

    private func importBackgroundImage(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            let previousFileName = backgroundImageFileName
            let importedFileName = try BackgroundImageStore.importImage(from: sourceURL)
            backgroundImageFileName = importedFileName
            backgroundImageEnabled = true
            backgroundFeedback = "背景图片已更新，可以继续调整虚化程度。"
            if !previousFileName.isEmpty {
                BackgroundImageStore.removeImage(fileName: previousFileName)
            }
        } catch {
            backgroundFeedback = "导入失败：\(error.localizedDescription)"
        }
    }

    private func exportData(_ format: ExportFormat) {
        do {
            let result = try ExportService.export(
                projects: dataStore.projects,
                tasks: dataStore.tasks,
                sessions: dataStore.sessions,
                interruptions: dataStore.interruptions,
                reflections: dataStore.reflections,
                snapshots: dataStore.snapshots,
                format: format
            )
            if case let .saved(url) = result {
                exportFeedback = "已保存到 \(url.path)"
            }
        } catch {
            exportFeedback = "导出失败：\(error.localizedDescription)"
        }
    }
}

private struct GrowthThemePicker: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 210), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(GrowthTheme.allCases) { theme in
                Button {
                    selection = theme.rawValue
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: theme.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                selection == theme.rawValue
                                    ? MossTheme.current.accentForeground
                                    : MossTheme.sage
                            )
                            .frame(width: 38, height: 38)
                            .background(
                                selection == theme.rawValue
                                    ? Color.white.opacity(0.14)
                                    : MossTheme.sage.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 12)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(theme.title)
                                .font(MossTypography.font(13, weight: .bold))
                            Text(theme.subtitle)
                                .font(.caption2)
                                .foregroundStyle(
                                    selection == theme.rawValue
                                        ? MossTheme.current.accentForeground.opacity(0.72)
                                        : Color.primary.opacity(0.58)
                                )
                                .lineLimit(2)
                        }
                        Spacer(minLength: 4)
                        if selection == theme.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MossTheme.current.accentForeground)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                    .padding(12)
                    .background(
                        selection == theme.rawValue
                            ? MossTheme.sage
                            : MossTheme.sage.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 15)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                selection == theme.rawValue
                                    ? MossTheme.sage
                                    : MossTheme.hairline,
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                .mossJellyHover(scale: 1.025, lift: 2, glow: 0.12)
                .accessibilityLabel("\(theme.title)，\(theme.subtitle)")
                .accessibilityValue(selection == theme.rawValue ? "已选择" : "未选择")
                .accessibilityAddTraits(selection == theme.rawValue ? .isSelected : [])
            }
        }
    }
}

private struct BackgroundImagePreview: View {
    let fileName: String
    let blurRadius: Double
    let imageOpacity: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MossTheme.quietFill)

                if let image = BackgroundImageStore.image(fileName: fileName) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.08)
                        .blur(radius: min(blurRadius * 0.45, 26))
                        .opacity(max(imageOpacity, 0.18))
                        .clipped()

                    Text("Moss")
                        .font(MossTypography.editorial(25, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                } else {
                    ContentUnavailableView(
                        "还没有背景图片",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("支持常见图片格式")
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MossTheme.hairline, lineWidth: 1)
            }
        }
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
                    .buttonStyle(MossJellyPlainButtonStyle())
                    .mossJellyHover(scale: 1.035, lift: 2, glow: 0.14)
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
                .buttonStyle(MossJellyPlainButtonStyle())
                .mossJellyHover(scale: 1.025, lift: 2, glow: 0.12)
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
                .buttonStyle(MossJellyPlainButtonStyle())
                .mossJellyHover(scale: 1.025, lift: 2, glow: 0.12)
                .accessibilityLabel(theme.title)
                .accessibilityValue(selection == theme.rawValue ? "已选择" : "未选择")
                .accessibilityAddTraits(selection == theme.rawValue ? .isSelected : [])
            }
        }
    }
}
