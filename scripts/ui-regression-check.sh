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
expect "Sources/Moss/TodayView.swift" "MossTypography.font(30, weight: .bold)"
expect "Sources/Moss/NotchPanel.swift" "MossTypography.font(20, weight: .bold)"
expect "Sources/Moss/NotchPanel.swift" "@AppStorage(\"islandOffsetX\") private var islandOffsetX"
expect "Sources/Moss/NotchPanel.swift" "DragGesture(minimumDistance: 4)"
expect "Sources/Moss/NotchPanel.swift" "handleIslandDrag"
expect "Sources/Moss/NotchPanel.swift" ".simultaneousGesture(islandDragGesture)"
expect "Sources/Moss/AppStore.swift" "func cancelStart()"
expect "Sources/Moss/TodayView.swift" "查看记录"
expect "Sources/Moss/TodayView.swift" "TodayFocusControls()"
expect "Sources/Moss/TodayView.swift" "结束并记录"
expect "Sources/Moss/TodayView.swift" "store.requestEnd()"
reject "Sources/Moss/TodayView.swift" ".onTapGesture(count: 2)"
expect "Sources/Moss/MenuBarView.swift" "store.startLastTask()"
expect "Sources/Moss/MenuBarView.swift" "private var preferredTask"
expect "Sources/Moss/NotchPanel.swift" "打开专注控制"
expect "Sources/Moss/TimelinePage.swift" "range = .day"
expect "Sources/Moss/TimelinePage.swift" "monthTextColor(duration: item.duration)"
expect "Sources/Moss/TimelinePage.swift" ".accessibilityLabel(item.date.formatted"
expect "Sources/Moss/ReviewView.swift" "MossTheme.current.accentForeground"
expect "Sources/Moss/SettingsView.swift" ".accessibilityAddTraits(selection =="
expect "Sources/Moss/SettingsView.swift" "也可以直接拖动专注岛"

print "UI regression checks passed"
