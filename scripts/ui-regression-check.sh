#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

contains() {
    local file="$1"
    local needle="$2"
    if command -v rg >/dev/null 2>&1; then
        rg -q --fixed-strings "$needle" "$file"
    else
        grep -Fq -- "$needle" "$file"
    fi
}

expect() {
    local file="$1"
    local needle="$2"
    contains "$root/$file" "$needle" || {
        print -u2 "missing: $needle ($file)"
        exit 1
    }
}

reject() {
    local file="$1"
    local needle="$2"
    ! contains "$root/$file" "$needle" || {
        print -u2 "unexpected: $needle ($file)"
        exit 1
    }
}

expect "Sources/Moss/MossApp.swift" "@NSApplicationDelegateAdaptor(MossAppDelegate.self)"
expect "Sources/Moss/MossApp.swift" "import AppKit"
expect "Sources/Moss/MossApp.swift" "final class MossAppDelegate: NSObject, NSApplicationDelegate"
expect "Sources/Moss/MossApp.swift" "applicationDidFinishLaunching"
expect "Sources/Moss/MossApp.swift" "applicationWillFinishLaunching"
expect "Sources/Moss/MossApp.swift" "applicationShouldHandleReopen"
expect "Sources/Moss/MossApp.swift" "mossApplicationReopenRequested"
expect "Sources/Moss/MossApp.swift" 'Button("打开 Moss 主窗口")'
expect "Sources/Moss/MossApp.swift" "NSApp.setActivationPolicy(launchSilently ? .accessory : .regular)"
expect "Sources/Moss/MossApp.swift" "let launchSilently = (UserDefaults.standard.object(forKey: \"launchSilently\") as? Bool) ?? true"
expect "Sources/Moss/MossApp.swift" "DispatchQueue.main.asyncAfter(deadline: .now() + 0.35)"
expect "Sources/Moss/MossApp.swift" '$0.title == "Moss · 专注岛" && $0.isVisible'
expect "Sources/Moss/MossApp.swift" "window.orderOut(nil)"
expect "Sources/Moss/MossApp.swift" "if store.mainWindowRequested"
reject "Sources/Moss/MossApp.swift" "terminate("
reject "Sources/Moss/MossApp.swift" ".hide("
expect "Sources/Moss/MossApp.swift" "Window(\"Moss · 专注岛\", id: \"main\")"
expect "Sources/Moss/MainView.swift" ".frame(minWidth: 900, minHeight: 620)"
expect "Sources/Moss/MainView.swift" 'case plan = "计划"'
expect "Sources/Moss/MainView.swift" "journalComposerRequest: journalComposerRequest"
expect "Sources/Moss/MainView.swift" 'Label("写手记", systemImage: "square.and.pencil")'
expect "Sources/Moss/MainView.swift" '.keyboardShortcut("j", modifiers: [.command])'
expect "Sources/Moss/PlanView.swift" 'case journal = "手记"'
expect "Sources/Moss/PlanView.swift" 'case schedule = "排程"'
expect "Sources/Moss/PlanView.swift" "PlanScheduleBoard("
expect "Sources/Moss/PlanView.swift" "private struct PlanEditorDraft: Identifiable"
expect "Sources/Moss/PlanView.swift" '.sheet(item: $newPlanDraft)'
expect "Sources/Moss/PlanView.swift" ".id(draft.id)"
reject "Sources/Moss/PlanView.swift" ".sheet(isPresented: \$isAddingPlan)"
expect "Sources/Moss/PlanScheduleBoard.swift" "struct PlanScheduleBoard: View"
expect "Sources/Moss/PlanScheduleBoard.swift" "DragGesture(minimumDistance: 4"
expect "Sources/Moss/PlanScheduleBoard.swift" "onSelectRange(lower, safeDuration)"
expect "Sources/Moss/PlanScheduleBoard.swift" "onMove(plan, dayShift, minuteShift)"
expect "Sources/Moss/PlanScheduleBoard.swift" "updated.scheduledAt = destination"
expect "Sources/Moss/PlanScheduleBoard.swift" "左右拖动这段时间链"
expect "Sources/Moss/PlanScheduleBoard.swift" ".mossPlanContextMenu(plan: plan"
expect "Sources/Moss/PlanScheduleBoard.swift" "private struct PlanContextMenuModifier: ViewModifier"
expect "Sources/Moss/PlanScheduleBoard.swift" 'Label("复制到下一时段", systemImage: "plus.square.on.square")'
expect "Sources/Moss/PlanScheduleBoard.swift" 'Label("标记完成", systemImage: "checkmark.circle")'
expect "Sources/Moss/PlanScheduleBoard.swift" 'Label("删除计划…", systemImage: "trash")'
expect "Sources/Moss/PlanScheduleBoard.swift" "dataStore.deletePlan(id: plan.id)"
expect "Sources/Moss/PlanView.swift" ".mossPlanContextMenu("
expect "Sources/Moss/PlanView.swift" 'Label("导入 Apple 手记", systemImage: "square.and.arrow.down")'
expect "Sources/Moss/PlanView.swift" 'Label("先做 5 分钟", systemImage: "flame.fill")'
expect "Sources/Moss/PlanView.swift" 'Label("开始专注", systemImage: "play.fill")'
expect "Sources/Moss/PlanView.swift" 'Label("写手记", systemImage: "square.and.pencil")'
expect "Sources/Moss/PlanView.swift" "private struct JournalEditorView: View"
expect "Sources/Moss/PlanView.swift" "private struct MossDatePicker: View"
expect "Sources/Moss/PlanView.swift" "private struct MossCalendar: View"
expect "Sources/Moss/PlanView.swift" "MossDatePicker(selection: \$scheduledAt)"
reject "Sources/Moss/PlanView.swift" ".datePickerStyle(.field)"
expect "Sources/Moss/PlanView.swift" "focusedField = .body"
expect "Sources/Moss/PlanView.swift" "automaticTitle(from: cleanBody)"
reject "Sources/Moss/PlanView.swift" '"记录日期",'
reject "Sources/Moss/TimelineFilterControls.swift" "Text(date, format: .dateTime.day())"
expect "Sources/Moss/TimelineFilterControls.swift" "Text(String(calendar.component(.day, from: date)))"
expect "Sources/Moss/Models.swift" "struct JournalRecordSummary: Identifiable, Hashable"
expect "Sources/Moss/DataStore.swift" "journalRecordSummaries = journalRecords.map(JournalRecordSummary.init)"
expect "Sources/Moss/PlanView.swift" "ForEach(dataStore.journalRecordSummaries)"
expect "Sources/Moss/PlanView.swift" "PlanShelfTabButtonStyle()"
expect "Sources/Moss/PlanView.swift" "hasPreloadedShelves"
expect "Sources/Moss/PlanView.swift" ".shelfLayer(isActive: shelf == .journal)"
reject "Sources/Moss/PlanView.swift" "Text(String(record.body.prefix(140)))"
expect "Sources/Moss/DataStore.swift" "func updateJournalRecord(_ record: JournalRecord)"
reject "Sources/Moss/PlanView.swift" "withAnimation("
expect "Sources/Moss/PlanView.swift" "allowedContentTypes: [.folder, .html, .pdf, .plainText]"
expect "Sources/Moss/PlanView.swift" "JournalImportService.records(from: url)"
expect "Sources/Moss/JournalImportService.swift" 'url.lastPathComponent.lowercased() == "index.html"'
expect "Sources/Moss/JournalImportService.swift" '"Entries"'
expect "Sources/Moss/PlanView.swift" "Moss 不会读取受保护的手记数据库"
expect "Sources/Moss/AppStore.swift" "dataStore.completePlannedEntry(linkedTo: current.taskID)"
reject "Sources/Moss/WindowConfigurator.swift" "window.identifier ="
expect "Sources/Moss/WindowConfigurator.swift" "let isTooSmall = window.frame.width < 900 || window.frame.height < 620"
expect "Sources/Moss/WindowConfigurator.swift" "let isOffscreen = !NSScreen.screens.contains"
expect "Sources/Moss/WindowConfigurator.swift" "window.setContentSize(NSSize(width: 1120, height: 760))"
expect "Sources/Moss/WindowConfigurator.swift" "window.center()"
expect "Sources/Moss/SettingsView.swift" "启动后仅在菜单栏驻留"
expect "Sources/Moss/SettingsView.swift" "@AppStorage(\"launchSilently\") private var launchSilently = true"
expect "Sources/Moss/SettingsView.swift" "下次启动时生效。"
expect "Sources/Moss/SettingsView.swift" ".scrollContentBackground(.hidden)"
reject "Sources/Moss/SettingsView.swift" "ScrollView {"
reject "Sources/Moss/SettingsView.swift" "step: 2"
expect "Sources/Moss/SettingsView.swift" 'Section("自定义背景")'
expect "Sources/Moss/SettingsView.swift" 'Section("成长主题")'
expect "Sources/Moss/SettingsView.swift" "GrowthThemePicker(selection:"
reject "Sources/Moss/SettingsView.swift" 'Toggle("显示主题桌宠"'
expect "Sources/Moss/SettingsView.swift" '"桌宠已经移入侧边栏的独立板块'
expect "Sources/Moss/SettingsView.swift" 'Picker("斗罗形态"'
expect "Sources/Moss/SettingsView.swift" ".fileImporter("
expect "Sources/Moss/SettingsView.swift" 'Slider(value: $backgroundBlurRadius, in: 0...60)'
expect "Sources/Moss/SettingsView.swift" 'Slider(value: $backgroundImageOpacity, in: 0.08...0.72)'
expect "Sources/Moss/MainView.swift" "MossWindowBackground()"
expect "Sources/Moss/BackgroundImageStore.swift" "startAccessingSecurityScopedResource()"
expect "Sources/Moss/MossWindowBackground.swift" ".blur(radius: blurRadius)"
expect "Sources/Moss/AppStore.swift" '$0.title == "Moss · 专注岛" && !($0 is NSPanel)'
expect "Sources/Moss/AppStore.swift" "window.makeKeyAndOrderFront(nil)"
expect "Sources/Moss/AppStore.swift" "NSApplication.shared.setActivationPolicy(.regular)"
expect "Sources/Moss/AppStore.swift" "NSApplication.shared.activate(ignoringOtherApps: true)"
expect "Sources/Moss/AppStore.swift" "MainWindowRouter.open?()"
reject "Sources/Moss/AppStore.swift" "identifier?.rawValue"
expect "Sources/Moss/MainView.swift" ".toolbar"
expect "Sources/Moss/MainView.swift" "@Environment(\\.openWindow) private var openWindow"
expect "Sources/Moss/MainView.swift" "MainWindowRouter.open = {"
expect "Sources/Moss/TodayView.swift" "ViewThatFits(in: .horizontal)"
expect "Sources/Moss/DesignSystem.swift" "var accentForeground"
reject "Sources/Moss/Typography.swift" '.id("\(fontTheme)-\(fontSize)")'
reject "Sources/Moss/MossApp.swift" ".id(colorTheme)"
reject "Sources/Moss/NotchPanel.swift" ".id(colorTheme)"
reject "Sources/Moss/TodayView.swift" ".font(.system(size: 30, weight: .bold, design: .rounded))"
reject "Sources/Moss/TodayView.swift" ".font(.system(size: 42, weight: .bold, design: .rounded))"
reject "Sources/Moss/NotchPanel.swift" ".font(.system(size: 20, weight: .bold, design: .rounded))"
expect "Sources/Moss/TodayView.swift" "MossPageHeader("
expect "Sources/Moss/TodayView.swift" "MossTypography.editorial(32, weight: .semibold)"
expect "Sources/Moss/NotchPanel.swift" "MossTypography.font(20, weight: .bold)"
reject "Sources/Moss/NotchPanel.swift" "DragGesture(minimumDistance: 4)"
reject "Sources/Moss/NotchPanel.swift" "panelController.beginDrag()"
reject "Sources/Moss/NotchPanel.swift" "panelController.updateDrag()"
reject "Sources/Moss/NotchPanel.swift" "panelController.endDrag()"
expect "Sources/Moss/NotchPanel.swift" "struct NativePanelDragHandle"
expect "Sources/Moss/NotchPanel.swift" "panel.performDrag(with: event)"
expect "Sources/Moss/NotchPanel.swift" "panel.isMovableByWindowBackground = false"
expect "Sources/Moss/NotchPanel.swift" "settleAfterDrag()"
expect "Sources/Moss/NotchPanel.swift" "NSAnimationContext.runAnimationGroup"
expect "Sources/Moss/NotchPanel.swift" "CAMediaTimingFunction("
expect "Sources/Moss/NotchPanel.swift" "private var idleLauncherSurface"
expect "Sources/Moss/NotchPanel.swift" "struct IslandQuickActionButton"
expect "Sources/Moss/NotchPanel.swift" "easeInOut(duration: 0.18)"
expect "Sources/Moss/IslandPanelGeometry.swift" "case launcher"
expect "Sources/Moss/NotchPanel.swift" "private var taskLauncher"
expect "Sources/Moss/NotchPanel.swift" "dataStore.startableTasks"
expect "Sources/Moss/NotchPanel.swift" "选择任务与计时方式"
expect "Sources/Moss/NotchPanel.swift" ".contextMenu {"
expect "Sources/Moss/NotchPanel.swift" "private var islandContextMenu"
expect "Sources/Moss/NotchPanel.swift" "@Published private(set) var isVisible"
expect "Sources/Moss/NotchPanel.swift" "func setVisible(_ visible: Bool, store: AppStore)"
expect "Sources/Moss/NotchPanel.swift" 'Label("隐藏专注岛", systemImage: "eye.slash")'
expect "Sources/Moss/NotchPanel.swift" 'islandControlButton("暂停"'
expect "Sources/Moss/NotchPanel.swift" 'islandControlButton("继续"'
reject "Sources/Moss/NotchPanel.swift" '@AppStorage("islandOffsetX")'
expect "Sources/Moss/NotchPanel.swift" "panel.setFrame(clamped, display: true, animate: false)"
expect "Sources/Moss/IslandPanelGeometry.swift" "enum IslandPanelGeometry"
expect "Sources/Moss/IslandPanelGeometry.swift" "static func clamped"
expect "Sources/Moss/IslandPanelGeometry.swift" "static func offset"
expect "Sources/Moss/IslandPanelGeometry.swift" "var notchGapWidth"
expect "Sources/Moss/IslandPanelGeometry.swift" "avoidsNotch: Bool = false"
expect "Sources/Moss/NotchPanel.swift" "auxiliaryTopLeftArea"
expect "Sources/Moss/NotchPanel.swift" "auxiliaryTopRightArea"
expect "Sources/Moss/NotchPanel.swift" "panelController.notchGapWidth"
expect "Sources/Moss/SettingsView.swift" "NotchPanelController.shared.resetPosition()"
expect "Sources/Moss/AppStore.swift" "func cancelStart()"
expect "Sources/Moss/AppStore.swift" "func presentReview()"
expect "Sources/Moss/AppStore.swift" "enterAwaitingReview(automatically: true)"
expect "Sources/Moss/AppStore.swift" "struct TransientNotice"
expect "Sources/Moss/TodayTaskLibraryView.swift" "查看专注记录"
expect "Sources/Moss/TodayView.swift" "TodayFocusControls()"
expect "Sources/Moss/TodayView.swift" "结束并记录"
expect "Sources/Moss/TodayView.swift" "store.requestEnd()"
reject "Sources/Moss/TodayView.swift" ".onTapGesture(count: 2)"
expect "Sources/Moss/MenuBarView.swift" "store.startLastTask()"
expect "Sources/Moss/MenuBarView.swift" "private var preferredTask"
expect "Sources/Moss/MenuBarView.swift" "@ObservedObject private var panelController = NotchPanelController.shared"
expect "Sources/Moss/MenuBarView.swift" 'panelController.setVisible(!panelController.isVisible, store: store)'
expect "Sources/Moss/MenuBarView.swift" 'panelController.isVisible ? "eye.slash" : "eye"'
expect "Sources/Moss/MossApp.swift" "DesktopWidgetPanelController.shared.show(store: store, dataStore: dataStore)"
expect "Sources/Moss/DesktopFocusWidget.swift" "final class DesktopWidgetPanelController: NSObject, ObservableObject, NSWindowDelegate"
expect "Sources/Moss/DesktopFocusWidget.swift" 'CGWindowLevelForKey(.desktopIconWindow)'
reject "Sources/Moss/DesktopFocusWidget.swift" 'CGWindowLevelForKey(.desktopWindow)'
expect "Sources/Moss/DesktopFocusWidget.swift" "panel.ignoresMouseEvents = false"
expect "Sources/Moss/DesktopFocusWidget.swift" "struct DesktopFocusWidgetView: View"
expect "Sources/Moss/DesktopFocusWidget.swift" "panel.isMovableByWindowBackground = true"
expect "Sources/Moss/DesktopFocusWidget.swift" "func windowDidMove(_ notification: Notification)"
expect "Sources/Moss/DesktopFocusWidget.swift" "override func acceptsFirstMouse(for event: NSEvent?) -> Bool"
expect "Sources/Moss/DesktopFocusWidget.swift" ".allowsHitTesting(false)"
reject "Sources/Moss/DesktopFocusWidget.swift" "panel.isMovableByWindowBackground = false"
expect "Sources/Moss/DesktopFocusWidget.swift" 'widgetActionButton("先做 5 分钟"'
expect "Sources/Moss/DesktopFocusWidget.swift" 'widgetActionButton("开始专注"'
expect "Sources/Moss/DesktopFocusWidget.swift" 'widgetActionButton("暂停"'
expect "Sources/Moss/DesktopFocusWidget.swift" 'widgetActionButton("继续"'
expect "Sources/Moss/DesktopFocusWidget.swift" 'Label("隐藏桌面小组件", systemImage: "eye.slash")'
expect "Sources/Moss/SettingsView.swift" '@AppStorage("showDesktopWidget") private var showDesktopWidget = false'
expect "Sources/Moss/SettingsView.swift" 'Section("桌面小组件")'
expect "Sources/Moss/MenuBarView.swift" "@ObservedObject private var desktopWidgetController = DesktopWidgetPanelController.shared"
expect "Sources/Moss/NotchPanel.swift" "打开专注控制"
expect "Sources/Moss/TimelinePage.swift" 'case all = "全部"'
expect "Sources/Moss/TimelinePage.swift" 'TextField("搜索 title、项目或心得"'
expect "Sources/Moss/TimelinePage.swift" "HistoryStatusFilter.allCases"
expect "Sources/Moss/TimelinePage.swift" "SessionStatusBadge(status: session.status)"
expect "Sources/Moss/TimelinePage.swift" "TimelineFilterMenu("
expect "Sources/Moss/TimelinePage.swift" "TimelineDateSelector(selection:"
expect "Sources/Moss/TimelinePage.swift" "TimelineNavigationButton("
expect "Sources/Moss/TimelinePage.swift" ".chartOverlay { proxy in"
expect "Sources/Moss/TimelinePage.swift" ".onContinuousHover { phase in"
expect "Sources/Moss/TimelinePage.swift" "hoveredChartDate"
expect "Sources/Moss/TimelinePage.swift" "Calendar.current.startOfDay(for: hoveredDate)"
reject "Sources/Moss/TimelinePage.swift" "timeIntervalSince(hoveredDate)"
expect "Sources/Moss/TimelinePage.swift" "width: .fixed(15)"
expect "Sources/Moss/TimelinePage.swift" ".frame(minWidth: 150, alignment: .trailing)"
expect "Sources/Moss/TimelinePage.swift" ".frame(height: 32, alignment: .topTrailing)"
reject "Sources/Moss/TimelinePage.swift" "width: .fixed(isHovered ? 20 : 15)"
reject "Sources/Moss/TimelinePage.swift" ".annotation(position: .top"
reject "Sources/Moss/TimelinePage.swift" 'Picker("分区"'
reject "Sources/Moss/TimelinePage.swift" 'Picker("Title"'
reject "Sources/Moss/TimelinePage.swift" 'Picker("状态"'
reject "Sources/Moss/TimelinePage.swift" 'DatePicker("选择日期"'
reject "Sources/Moss/TimelinePage.swift" 'Picker("时间范围"'
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineFilterMenu"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineDateSelector"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineCalendarPopover"
expect "Sources/Moss/TimelineFilterControls.swift" "private var dayGrid"
expect "Sources/Moss/TimelineFilterControls.swift" "Button(\"今天\")"
reject "Sources/Moss/TimelineFilterControls.swift" ".datePickerStyle(.graphical)"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineNavigationButton"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineRangePicker"
expect "Sources/Moss/TimelineFilterControls.swift" ".matchedGeometryEffect("
expect "Sources/Moss/TimelineFilterControls.swift" ".menuIndicator(.hidden)"
expect "Sources/Moss/TimelineFilterControls.swift" ".accessibilityLabel(accessibilityLabel)"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineDownChevron"
expect "Sources/Moss/TimelineFilterControls.swift" "StrokeStyle(lineWidth: 1.35"
expect "Sources/Moss/InsightsView.swift" "title: growthTheme.journalTitle"
expect "Sources/Moss/InsightsView.swift" "IslandMapCard(metrics: analytics.titleMetrics)"
expect "Sources/Moss/TitleDetailView.swift" 'Text("成长曲线")'
expect "Sources/Moss/FocusAnalytics.swift" "experienceToNextLevel"
expect "Sources/Moss/ReviewView.swift" "MossTheme.current.accentForeground"
expect "Sources/Moss/SettingsView.swift" ".accessibilityAddTraits(selection =="
expect "Sources/Moss/SettingsView.swift" "也可以直接拖动专注岛"
expect "Sources/Moss/TodayView.swift" "store.currentTaskID"
expect "Sources/Moss/ArchiveView.swift" "dataStore.restoreTask(id: task.id)"
expect "Sources/Moss/DataStore.swift" "func restoreBackup()"
expect "Sources/Moss/DataStore.swift" "storageWritesAllowed = false"
expect "Sources/Moss/DataStore.swift" "static func backupURL"
expect "Sources/Moss/ExportService.swift" "enum ExportResult"
expect "Sources/Moss/ExportService.swift" "var interruptions: [Interruption]"
expect "Sources/Moss/ExportService.swift" "var reflections: [Reflection]"
expect "Sources/Moss/ExportService.swift" "var snapshots: [DailySnapshot]"
expect "Sources/Moss/DesignSystem.swift" "enum MossSurfaceKind"
expect "Sources/Moss/DesignSystem.swift" "struct MossPageHeader"
expect "Sources/Moss/DesignSystem.swift" "struct MossMetric"
expect "Sources/Moss/DesignSystem.swift" "func mossJellyHover("
expect "Sources/Moss/DesignSystem.swift" "struct MossJellyPlainButtonStyle"
expect "Sources/Moss/DesignSystem.swift" ".spring(response: 0.30, dampingFraction: 0.62"
reject "Sources/Moss/DesignSystem.swift" "isHovered ? MossTheme.sage.opacity(0.26) : borderColor"
expect "Sources/Moss/SettingsView.swift" ".mossJellyHover(scale: 1.025"
expect "Sources/Moss/TodayTaskLibraryView.swift" ".mossJellyHover(scale: 1.022"
expect "Sources/Moss/TimelineFilterControls.swift" ".mossJellyHover(scale: 1.035"
expect "Sources/Moss/InsightsView.swift" ".mossJellyHover(scale: 1.035"
expect "Sources/Moss/Typography.swift" "static func editorial"
expect "Sources/Moss/MainView.swift" 'case .insights: "成长志"'
expect "Sources/Moss/MainView.swift" ".tint(MossTheme.sage)"
expect "Sources/Moss/TodayView.swift" "续进你的长期积累"
expect "Sources/Moss/TodayView.swift" "private func idleQuickStart(task: FocusTask)"
expect "Sources/Moss/TodayView.swift" "接着做"
expect "Sources/Moss/TodayView.swift" "全部积累"
expect "Sources/Moss/TodayView.swift" "当前领域"
expect "Sources/Moss/TodayView.swift" "MossCard(kind: .hero"
expect "Sources/Moss/InsightsView.swift" '"你的投入，正在成为可以回望的作品。"'
expect "Sources/Moss/InsightsView.swift" 'Text("积累编年史")'
expect "Sources/Moss/InsightsView.swift" "growthTheme.evidenceTitle"
expect "Sources/Moss/InsightsView.swift" 'Text("万时修炼体系")'
expect "Sources/Moss/InsightsView.swift" "growthTheme.evidenceTitle"
expect "Sources/Moss/InsightsView.swift" "growthTheme.achievementPresentation(for:"
expect "Sources/Moss/GrowthThemePresentation.swift" 'themed = ("初次冥想"'
expect "Sources/Moss/GrowthThemePresentation.swift" 'themed = ("七日连修"'
expect "Sources/Moss/GrowthThemePresentation.swift" 'themed = ("首枚千年魂环"'
expect "Sources/Moss/FocusCompletionView.swift" '"本次修炼已经完成"'
expect "Sources/Moss/TodayView.swift" '"开始修炼"'
expect "Sources/Moss/MainView.swift" ".journalTitle"
expect "Sources/Moss/InsightsView.swift" 'Text("1 小时 = 100 年魂环")'
expect "Sources/Moss/InsightsView.swift" 'Text("查看完整等级表")'
expect "Sources/Moss/FocusCultivationRank.swift" "static let masteryHours = 10_000.0"
expect "Sources/Moss/FocusCultivationRank.swift" "enum GrowthTheme"
expect "Sources/Moss/FocusCultivationRank.swift" "case douluo"
expect "Sources/Moss/InsightsView.swift" "themedGrowthModule"
expect "Sources/Moss/InsightsView.swift" 'Text("主题档案")'
expect "Sources/Moss/InsightsView.swift" 'Text("已装备魂环 · \(snapshot.rank.realm.title)最多 \(snapshot.soulRingCapacity) 个")'
expect "Sources/Moss/InsightsView.swift" '"候选领域 · \(snapshot.unequippedSoulRingCandidates.count) 个"'
expect "Sources/Moss/ThemeAvatar.swift" "var soulRingCapacity:"
expect "Sources/Moss/ThemeAvatar.swift" "var equippedSoulRings:"
expect "Sources/Moss/ThemeAvatar.swift" "var unequippedSoulRingCandidates:"
expect "Sources/Moss/ThemeAvatar.swift" "var trainingRecommendations:"
expect "Sources/Moss/ThemeAvatar.swift" "var synergyPower:"
expect "Sources/Moss/ThemeAvatar.swift" "private var mechaRecommendation:"
expect "Sources/Moss/ThemeAvatar.swift" "private var soulSpiritRecommendation:"
expect "Sources/Moss/ThemeAvatar.swift" "private var synergyRecommendation:"
expect "Sources/Moss/ThemeAvatar.swift" "enum ThemeOrganizationKind"
expect "Sources/Moss/ThemeAvatar.swift" "var organizationNodes:"
expect "Sources/Moss/ThemeAvatar.swift" "var organizationPower:"
expect "Sources/Moss/ThemeAvatar.swift" "var currentAffiliation:"
expect "Sources/Moss/InsightsView.swift" 'Text("主动修炼搭配")'
expect "Sources/Moss/InsightsView.swift" '"协同战力 +\(snapshot.synergyPower.formatted())"'
expect "Sources/Moss/InsightsView.swift" 'Button("开始修炼")'
expect "Sources/Moss/InsightsView.swift" 'Label("势力与组织"'
expect "Sources/Moss/InsightsView.swift" '"个人修炼是核心；组织只承接更大规模的项目与长期积累'
expect "Sources/Moss/InsightsView.swift" '"当前舞台 · \(snapshot.currentAffiliation)"'
expect "Sources/Moss/ThemeCompanionPage.swift" "snapshot.equippedSoulRings.indices"
expect "Sources/Moss/InsightsView.swift" 'Text("当前魂灵 · 由未归档的大项目生成")'
expect "Sources/Moss/InsightsView.swift" 'Text("封存魂灵")'
expect "Sources/Moss/InsightsView.swift" 'Text("封存魂环")'
expect "Sources/Moss/InsightsView.swift" 'Text("战力")'
expect "Sources/Moss/ThemeAvatar.swift" "struct ThemeAvatarSnapshot"
expect "Sources/Moss/ThemeAvatar.swift" "var martialSouls:"
expect "Sources/Moss/ThemeAvatar.swift" "var activeSoulSpirits:"
expect "Sources/Moss/ThemeAvatar.swift" "var archivedSoulSpirits:"
expect "Sources/Moss/Models.swift" "var archivedAt: Date?"
expect "Sources/Moss/DataStore.swift" "archivedAt = archived ? .now : nil"
expect "Sources/Moss/ArchiveView.swift" "旧记录未保存归档日期"
expect "Sources/Moss/MainView.swift" 'case companion = "桌宠"'
expect "Sources/Moss/MainView.swift" "case .companion: ThemeCompanionPage()"
expect "Sources/Moss/ThemeCompanionPage.swift" "struct ThemeCompanionPage"
expect "Sources/Moss/ThemeCompanionPage.swift" 'Label("点击和伙伴说话"'
expect "Sources/Moss/ThemeCompanionPage.swift" 'Text("动画预留")'
expect "Sources/Moss/ThemeCompanionPage.swift" 'Text("伙伴建议")'
expect "Sources/Moss/ThemeCompanionPage.swift" 'boardTitle('
reject "Sources/Moss/MossApp.swift" "ThemeCompanionPanelController.shared.show("
expect "Sources/Moss/FocusCultivationRank.swift" "case titledDouluo"
expect "Sources/Moss/FocusCultivationRank.swift" "case limitDouluo"
expect "Sources/Moss/FocusCultivationRank.swift" "case millionYear"
expect "Sources/Moss/InsightsView.swift" "analytics.recentMonths"
expect "Sources/Moss/InsightsView.swift" "MonthlyChronicleCard"
expect "Sources/Moss/FocusHeatmapView.swift" "@Environment(\\.colorScheme)"
expect "Sources/Moss/FocusHeatmapView.swift" "MossTheme.mint.opacity"
expect "Sources/Moss/FocusHeatmapView.swift" "MossTheme.mint"
expect "Sources/Moss/MainView.swift" "SidebarSectionRow"
reject "Sources/Moss/MainView.swift" "List(AppSection.allCases, selection: selection)"
expect "Sources/Moss/MainView.swift" "@Namespace private var sidebarMotion"
expect "Sources/Moss/MainView.swift" ".matchedGeometryEffect(id: \"sidebar-selection\""
expect "Sources/Moss/MainView.swift" ".matchedGeometryEffect(id: \"sidebar-hover\""
expect "Sources/Moss/MainView.swift" "JellySidebarButtonStyle"
expect "Sources/Moss/MainView.swift" ".spring(response: 0.22, dampingFraction: 0.52"
reject "Sources/Moss/MainView.swift" "DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.055))"
reject "Sources/Moss/MainView.swift" "navigationRevision"
expect "Sources/Moss/MainView.swift" "withTransaction(transaction)"
expect "Sources/Moss/DataStore.swift" "private(set) var analyticsSnapshot = FocusAnalyticsSnapshot(sessions: [])"
expect "Sources/Moss/TodayView.swift" "dataStore.analyticsSnapshot"
expect "Sources/Moss/InsightsView.swift" "dataStore.analyticsSnapshot"
expect "Sources/Moss/TimelinePage.swift" "MossPageHeader("
expect "Sources/Moss/TimelinePage.swift" "MossMetric("
expect "Sources/Moss/TodayTaskPresentation.swift" "static let visibleLimit = 6"
expect "Sources/Moss/TodayTaskLibraryView.swift" "LazyVGrid"
expect "Sources/Moss/TodayTaskLibraryView.swift" "GridItem(.adaptive(minimum: 210, maximum: 270)"
expect "Sources/Moss/TodayTaskLibraryView.swift" ".draggable(task.id.uuidString)"
expect "Sources/Moss/TodayTaskLibraryView.swift" ".dropDestination(for: String.self)"
expect "Sources/Moss/TodayTaskLibraryView.swift" "Menu(\"移动到项目\")"
expect "Sources/Moss/TodayTaskLibraryView.swift" "展开另外"
expect "Sources/Moss/TodayTaskLibraryView.swift" "@Environment(\\.accessibilityReduceMotion)"
expect "Sources/Moss/TodayView.swift" "private var focusDashboard"
expect "Sources/Moss/TodayView.swift" "private var insightRail"
reject "Sources/Moss/TodayView.swift" "private var taskAndWeather"
reject "Sources/Moss/TodayView.swift" "private var timelineAndFeedback"
reject "Sources/Moss/TodayView.swift" "ForEach(tasks) { task in"
reject "Sources/Moss/TodayView.swift" "private struct TaskCapsuleRow"

print "UI regression checks passed"
