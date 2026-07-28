#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

expect() {
    local file="$1"
    local needle="$2"
    rg -q --fixed-strings "$needle" "$root/$file" || {
        print -u2 "missing: $needle ($file)"
        exit 1
    }
}

reject() {
    local file="$1"
    local needle="$2"
    ! rg -q --fixed-strings "$needle" "$root/$file" || {
        print -u2 "unexpected: $needle ($file)"
        exit 1
    }
}

expect "Sources/Moss/MossApp.swift" "@NSApplicationDelegateAdaptor(MossAppDelegate.self)"
expect "Sources/Moss/MossApp.swift" "import AppKit"
expect "Sources/Moss/MossApp.swift" "final class MossAppDelegate: NSObject, NSApplicationDelegate"
expect "Sources/Moss/MossApp.swift" "applicationDidFinishLaunching"
expect "Sources/Moss/MossApp.swift" "applicationWillFinishLaunching"
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
reject "Sources/Moss/WindowConfigurator.swift" "window.identifier ="
expect "Sources/Moss/WindowConfigurator.swift" "let isTooSmall = window.frame.width < 900 || window.frame.height < 620"
expect "Sources/Moss/WindowConfigurator.swift" "let isOffscreen = !NSScreen.screens.contains"
expect "Sources/Moss/WindowConfigurator.swift" "window.setContentSize(NSSize(width: 1120, height: 760))"
expect "Sources/Moss/WindowConfigurator.swift" "window.center()"
expect "Sources/Moss/SettingsView.swift" "启动后仅在菜单栏驻留"
expect "Sources/Moss/SettingsView.swift" "@AppStorage(\"launchSilently\") private var launchSilently = true"
expect "Sources/Moss/SettingsView.swift" "下次启动时生效。"
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
expect "Sources/Moss/NotchPanel.swift" "DragGesture(minimumDistance: 4)"
expect "Sources/Moss/NotchPanel.swift" "panelController.beginDrag()"
expect "Sources/Moss/NotchPanel.swift" "panelController.updateDrag()"
expect "Sources/Moss/NotchPanel.swift" "panelController.endDrag()"
reject "Sources/Moss/NotchPanel.swift" '@AppStorage("islandOffsetX")'
expect "Sources/Moss/NotchPanel.swift" "panel.setFrame(clamped, display: true, animate: false)"
expect "Sources/Moss/IslandPanelGeometry.swift" "enum IslandPanelGeometry"
expect "Sources/Moss/IslandPanelGeometry.swift" "static func clamped"
expect "Sources/Moss/IslandPanelGeometry.swift" "static func offset"
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
expect "Sources/Moss/NotchPanel.swift" "打开专注控制"
expect "Sources/Moss/TimelinePage.swift" 'case all = "全部"'
expect "Sources/Moss/TimelinePage.swift" 'TextField("搜索 title、项目或心得"'
expect "Sources/Moss/TimelinePage.swift" "HistoryStatusFilter.allCases"
expect "Sources/Moss/TimelinePage.swift" "SessionStatusBadge(status: session.status)"
expect "Sources/Moss/TimelinePage.swift" "TimelineFilterMenu("
expect "Sources/Moss/TimelinePage.swift" "TimelineDateSelector(selection:"
expect "Sources/Moss/TimelinePage.swift" "TimelineNavigationButton("
reject "Sources/Moss/TimelinePage.swift" 'Picker("分区"'
reject "Sources/Moss/TimelinePage.swift" 'Picker("Title"'
reject "Sources/Moss/TimelinePage.swift" 'Picker("状态"'
reject "Sources/Moss/TimelinePage.swift" 'DatePicker("选择日期"'
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineFilterMenu"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineDateSelector"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineNavigationButton"
expect "Sources/Moss/TimelineFilterControls.swift" ".menuIndicator(.hidden)"
expect "Sources/Moss/TimelineFilterControls.swift" ".accessibilityLabel(accessibilityLabel)"
expect "Sources/Moss/TimelineFilterControls.swift" "struct TimelineDownChevron"
expect "Sources/Moss/TimelineFilterControls.swift" "StrokeStyle(lineWidth: 1.35"
expect "Sources/Moss/InsightsView.swift" 'title: "成长志"'
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
expect "Sources/Moss/Typography.swift" "static func editorial"
expect "Sources/Moss/MainView.swift" 'case .insights: "成长志"'
expect "Sources/Moss/MainView.swift" ".tint(MossTheme.sage)"
expect "Sources/Moss/TodayView.swift" "加入"
expect "Sources/Moss/TodayView.swift" "全部积累"
expect "Sources/Moss/TodayView.swift" "当前领域"
expect "Sources/Moss/TodayView.swift" "MossCard(kind: .hero"
expect "Sources/Moss/InsightsView.swift" 'Text("你的投入，正在成为可以回望的作品。")'
expect "Sources/Moss/InsightsView.swift" 'Text("积累编年史")'
expect "Sources/Moss/InsightsView.swift" 'Text("成长证据")'
expect "Sources/Moss/InsightsView.swift" "analytics.recentMonths"
expect "Sources/Moss/InsightsView.swift" "MonthlyChronicleCard"
expect "Sources/Moss/MainView.swift" "SidebarSectionRow"
reject "Sources/Moss/MainView.swift" "List(AppSection.allCases, selection: selection)"
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
