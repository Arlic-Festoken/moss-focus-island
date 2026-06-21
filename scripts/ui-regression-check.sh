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
expect "Sources/Moss/AppStore.swift" "NSApplication.shared.activate(ignoringOtherApps: true)"
expect "Sources/Moss/AppStore.swift" "MainWindowRouter.open?()"
reject "Sources/Moss/AppStore.swift" "identifier?.rawValue"

print "UI regression checks passed"
