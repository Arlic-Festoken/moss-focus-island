import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today = "今天"
    case plan = "计划"
    case timeline = "时间线"
    case insights = "洞察"
    case companion = "桌宠"
    case archive = "归档"
    case settings = "设置"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insights: "成长志"
        default: rawValue
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .plan: "calendar.badge.clock"
        case .timeline: "waveform.path.ecg"
        case .insights: "book.closed.fill"
        case .companion: "person.crop.circle.fill"
        case .archive: "archivebox"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("selectedSection") private var selectedSectionRaw = AppSection.today.rawValue
    @AppStorage("backgroundImageEnabled") private var backgroundImageEnabled = false
    @AppStorage("backgroundImageFileName") private var backgroundImageFileName = ""
    @AppStorage("growthTheme") private var growthThemeRaw = GrowthTheme.douluo.rawValue
    @State private var isAddingTask = false
    @State private var isAddingProject = false
    @State private var journalComposerRequest: UUID?
    @State private var selectedSection: AppSection?
    @State private var detailSection: AppSection?
    @State private var hoveredSection: AppSection?
    @Namespace private var sidebarMotion

    private var sidebarSection: AppSection {
        selectedSection
            ?? AppSection(rawValue: selectedSectionRaw)
            ?? .today
    }

    private var visibleSection: AppSection {
        detailSection ?? sidebarSection
    }

    private var usesCustomBackground: Bool {
        backgroundImageEnabled
            && BackgroundImageStore.imageURL(fileName: backgroundImageFileName) != nil
    }

    var body: some View {
        ZStack {
            MossWindowBackground()

            NavigationSplitView {
                VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MossTheme.current.accentForeground)
                        .frame(width: 31, height: 31)
                        .background(MossTheme.sage, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Moss")
                            .font(MossTypography.editorial(19, weight: .semibold))
                        Text("专注岛")
                            .font(MossTypography.font(10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 12)

                Button {
                    openJournalComposer()
                } label: {
                    Label("写手记", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
                .keyboardShortcut("j", modifiers: [.command])
                .help("直接写一篇手记 · ⌘J")
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(AppSection.allCases) { section in
                            SidebarSectionRow(
                                section: section,
                                displayTitle: section == .insights
                                    ? (GrowthTheme(rawValue: growthThemeRaw) ?? .douluo).journalTitle
                                    : section.title,
                                isSelected: sidebarSection == section,
                                isHovered: hoveredSection == section,
                                motionNamespace: sidebarMotion,
                                reduceMotion: reduceMotion,
                                onHoverChange: { isHovering in
                                    updateHover(section, isHovering: isHovering)
                                }
                            ) {
                                navigate(to: section)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity, alignment: .top)

                SidebarFocusStatus()
                    .padding(14)
                }
                .background(.ultraThinMaterial)
                .navigationSplitViewColumnWidth(min: 185, ideal: 208, max: 240)
            } detail: {
                Group {
                    switch visibleSection {
                    case .today:
                        TodayView {
                            navigate(to: .timeline)
                        }
                    case .plan:
                        PlanView(
                            journalComposerRequest: journalComposerRequest,
                            onJournalComposerRequestHandled: { request in
                                guard journalComposerRequest == request else { return }
                                journalComposerRequest = nil
                            }
                        )
                    case .timeline: TimelinePage()
                    case .insights: InsightsView()
                    case .companion: ThemeCompanionPage()
                    case .archive: ArchiveView()
                    case .settings: SettingsView()
                    }
                }
                .background(MossTheme.paper.opacity(usesCustomBackground ? 0.70 : 1))
            }
            .background(Color.clear)
        }
        .tint(MossTheme.sage)
        .background(WindowConfigurator())
        .frame(minWidth: 900, minHeight: 620)
        .onAppear {
            MainWindowRouter.open = {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                focusToolbarControls

                Menu {
                    Button("新任务") { isAddingTask = true }
                    Button("新项目 / 文件夹") { isAddingProject = true }
                } label: {
                    Label("新建", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingTask) {
            TaskEditorView()
        }
        .sheet(isPresented: $isAddingProject) {
            ProjectEditorView()
        }
        .sheet(isPresented: $store.isReviewPresented) {
            ReviewView()
                .environmentObject(store)
        }
        .alert(
            "欢迎回来",
            isPresented: Binding(
                get: { store.wakeGapMessage != nil },
                set: { if !$0 { store.wakeGapMessage = nil } }
            )
        ) {
            Button("知道了") { store.wakeGapMessage = nil }
        } message: {
            Text(store.wakeGapMessage ?? "")
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let issue = dataStore.storageIssue {
                    StorageIssueBanner(issue: issue)
                        .environmentObject(dataStore)
                }
                if let notice = store.transientNotice {
                    Text(notice.message)
                        .font(MossTypography.font(13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 12)
        }
        .animation(.easeInOut(duration: 0.22), value: store.transientNotice?.id)
        .overlay(alignment: .topTrailing) {
            if let receipt = store.completionReceipt {
                FocusCompletionView(receipt: receipt)
                    .padding(.top, 54)
                    .padding(.trailing, 20)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .trailing).combined(with: .opacity)
                    )
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.42, dampingFraction: 0.86),
            value: store.completionReceipt?.id
        )
    }

    private func navigate(to section: AppSection) {
        guard section != sidebarSection else { return }

        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .spring(response: 0.34, dampingFraction: 0.68, blendDuration: 0.08)
        ) {
            selectedSection = section
        }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            detailSection = section
            selectedSectionRaw = section.rawValue
        }
    }

    private func openJournalComposer() {
        journalComposerRequest = UUID()
        navigate(to: .plan)
    }

    private func updateHover(_ section: AppSection, isHovering: Bool) {
        withAnimation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .spring(response: 0.30, dampingFraction: 0.72, blendDuration: 0.06)
        ) {
            if isHovering {
                hoveredSection = section
            } else if hoveredSection == section {
                hoveredSection = nil
            }
        }
    }

    @ViewBuilder
    private var focusToolbarControls: some View {
        switch store.phase {
        case .idle:
            Button {
                store.startLastTask()
            } label: {
                Label("开始上一次", systemImage: "play.fill")
            }
            .help("⌘⇧F")
        case .preparing:
            Button {
                store.cancelStart()
            } label: {
                Label("取消开始", systemImage: "xmark")
            }
        case .focusing:
            Button {
                store.pause()
            } label: {
                Label("暂停", systemImage: "pause.fill")
            }
            Button {
                store.requestEnd()
            } label: {
                Label("结束并记录", systemImage: "stop.fill")
            }
        case .paused:
            Button {
                store.resume()
            } label: {
                Label("继续", systemImage: "play.fill")
            }
            Button {
                store.requestEnd()
            } label: {
                Label("结束并记录", systemImage: "stop.fill")
            }
        case .breakTime:
            Button {
                store.skipBreak()
            } label: {
                Label("结束休息", systemImage: "forward.end.fill")
            }
        case .awaitingReview:
            Button {
                store.presentReview()
            } label: {
                Label("完成记录", systemImage: "checkmark")
            }
        }
    }
}

private struct StorageIssueBanner: View {
    @EnvironmentObject private var dataStore: DataStore
    let issue: DataStoreIssue

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: issue.kind == .recovered ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(issue.kind == .recovered ? MossTheme.mint : MossTheme.apricot)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(MossTypography.font(12, weight: .semibold))
                Text(issue.message)
                    .font(MossTypography.font(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if issue.canRestoreBackup {
                Button("从备份恢复") {
                    dataStore.restoreBackup()
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
            }
            Button {
                dataStore.dismissStorageIssue()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(MossJellyPlainButtonStyle())
            .accessibilityLabel("暂时关闭数据提示")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 680)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(MossTheme.apricot.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
    }
}

private struct SidebarSectionRow: View {
    let section: AppSection
    let displayTitle: String
    let isSelected: Bool
    let isHovered: Bool
    let motionNamespace: Namespace.ID
    let reduceMotion: Bool
    let onHoverChange: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected || isHovered ? MossTheme.sage : .secondary)
                    .frame(width: 25, height: 25)
                    .background(
                        MossTheme.sage.opacity(isSelected ? 0.16 : isHovered ? 0.10 : 0),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .scaleEffect(isSelected ? 1.05 : isHovered ? 1.12 : 1)
                    .rotationEffect(.degrees(isHovered && !reduceMotion ? -2.5 : 0))
                Text(displayTitle)
                    .font(MossTypography.font(13, weight: isSelected ? .semibold : .medium))
                Spacer()
                if isSelected {
                    Circle()
                        .fill(MossTheme.sage)
                        .frame(width: 7, height: 7)
                        .shadow(color: MossTheme.sage.opacity(0.55), radius: 5)
                        .transition(.scale(scale: 0.25).combined(with: .opacity))
                } else if isHovered {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MossTheme.sage.opacity(0.78))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected || isHovered ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .offset(x: isHovered && !reduceMotion ? 3 : 0)
            .background { animatedBackground }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(JellySidebarButtonStyle(reduceMotion: reduceMotion))
        .onHover(perform: onHoverChange)
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .spring(response: 0.32, dampingFraction: 0.62, blendDuration: 0.08),
            value: isHovered
        )
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .spring(response: 0.36, dampingFraction: 0.66, blendDuration: 0.08),
            value: isSelected
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var animatedBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MossTheme.sage.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MossTheme.sage.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: MossTheme.sage.opacity(0.12), radius: 10, y: 4)
                .matchedGeometryEffect(id: "sidebar-selection", in: motionNamespace)
        } else if isHovered {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MossTheme.sage.opacity(0.095))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MossTheme.sage.opacity(0.14), lineWidth: 1)
                )
                .matchedGeometryEffect(id: "sidebar-hover", in: motionNamespace)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.clear)
        }
    }
}

private struct JellySidebarButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.035 : 0)
            .animation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .spring(response: 0.22, dampingFraction: 0.52, blendDuration: 0.06),
                value: configuration.isPressed
            )
    }
}

private struct SidebarFocusStatus: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore

    var body: some View {
        let analytics = dataStore.analyticsSnapshot
        VStack(alignment: .leading, spacing: 10) {
            if store.phase == .idle {
                HStack {
                    Label("岛屿安静着", systemImage: "leaf")
                        .font(MossTypography.font(11, weight: .semibold))
                        .foregroundStyle(MossTheme.sage)
                    Spacer()
                    Text("⌘⇧F")
                        .font(MossTypography.font(9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("近 7 天 · \(analytics.recentFocus.compactDuration)")
                        .font(MossTypography.font(11, weight: .medium))
                    Text("全部积累 · \(analytics.totalFocus.compactDuration)")
                        .font(MossTypography.font(10))
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    ProgressRing(progress: store.progress, lineWidth: 4)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sidebarPhaseTitle)
                            .font(.caption.weight(.semibold))
                        Text(store.displayTime.clockString)
                            .font(MossTypography.font(14, weight: .bold))
                            .monospacedDigit()
                    }
                    Spacer()
                }
                Text(store.currentTaskTitle)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MossTheme.sage.opacity(0.075), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(MossTheme.sage.opacity(0.12), lineWidth: 1)
        )
    }

    private var sidebarPhaseTitle: String {
        switch store.phase {
        case .idle: "未开始"
        case .preparing: "进入状态"
        case .focusing: "专注中"
        case .paused: "暂停中"
        case .breakTime: "休息中"
        case .awaitingReview: "等待记录"
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 5
    var tint: Color = MossTheme.sage

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.015, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
