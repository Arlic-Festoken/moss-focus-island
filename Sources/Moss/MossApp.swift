import AppKit
import SwiftUI

extension Notification.Name {
    static let mossApplicationReopenRequested = Notification.Name(
        "com.zhikanghuang.moss.applicationReopenRequested"
    )
}

final class MossAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let launchSilently = (UserDefaults.standard.object(forKey: "launchSilently") as? Bool) ?? true
        NSApp.setActivationPolicy(launchSilently ? .accessory : .regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchSilently = (UserDefaults.standard.object(forKey: "launchSilently") as? Bool) ?? true
        guard launchSilently else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSApp.windows
                .filter { $0.title == "Moss · 专注岛" && $0.isVisible }
                .forEach { window in
                    window.orderOut(nil)
                }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        NotificationCenter.default.post(name: .mossApplicationReopenRequested, object: nil)
        return true
    }
}

@main
struct MossApp: App {
    @NSApplicationDelegateAdaptor(MossAppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @StateObject private var dataStore: DataStore
    @StateObject private var cloudSync: CloudSyncController
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue

    init() {
        let dataStore = DataStore()
        _dataStore = StateObject(wrappedValue: dataStore)
        _cloudSync = StateObject(
            wrappedValue: CloudSyncController(dataStore: dataStore)
        )
    }

    private var accent: Color {
        MossColorTheme(rawValue: colorTheme)?.accent ?? MossTheme.sage
    }

    var body: some Scene {
        Window("Moss · 专注岛", id: "main") {
            Group {
                if store.mainWindowRequested {
                    MainView()
                } else {
                    Color.clear
                        .accessibilityHidden(true)
                }
            }
                .environmentObject(store)
                .environmentObject(dataStore)
                .environmentObject(cloudSync)
                .mossTypography()
                .tint(accent)
                .task {
                    store.configure(with: dataStore)
                    cloudSync.startIfEnabled()
                    NotchPanelController.shared.show(store: store)
                    DesktopWidgetPanelController.shared.show(store: store, dataStore: dataStore)
                    DesktopCompanionPanelController.shared.show(store: store, dataStore: dataStore)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: .mossApplicationReopenRequested)
                ) { _ in
                    store.openMainWindow()
                }
        }
        .defaultSize(width: 1120, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("打开 Moss 主窗口") {
                    store.openMainWindow()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Divider()

                Button("开始上一次任务") {
                    store.startLastTask()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button(store.phase == .paused ? "继续专注" : "暂停专注") {
                    store.phase == .paused ? store.resume() : store.pause()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(store.phase != .preparing && store.phase != .focusing && store.phase != .paused)

                Button("结束当前专注") {
                    store.requestEnd()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(store.phase != .preparing && store.phase != .focusing && store.phase != .paused)
            }
        }

        MenuBarExtra("Moss", systemImage: store.phase == .breakTime ? "cup.and.saucer.fill" : "leaf.fill") {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(dataStore)
                .environmentObject(cloudSync)
                .mossTypography()
                .tint(accent)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(dataStore)
                .environmentObject(cloudSync)
                .mossTypography()
                .tint(accent)
        }
    }
}
