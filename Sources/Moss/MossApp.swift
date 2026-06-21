import AppKit
import SwiftUI

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
}

@main
struct MossApp: App {
    @NSApplicationDelegateAdaptor(MossAppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore()
    @StateObject private var dataStore = DataStore()
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue

    private var accent: Color {
        MossColorTheme(rawValue: colorTheme)?.accent ?? MossTheme.sage
    }

    var body: some Scene {
        Window("Moss · 专注岛", id: "main") {
            MainView()
                .environmentObject(store)
                .environmentObject(dataStore)
                .mossTypography()
                .tint(accent)
                .task {
                    store.configure(with: dataStore)
                    NotchPanelController.shared.show(store: store)
                }
        }
        .defaultSize(width: 1120, height: 760)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
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
                .mossTypography()
                .tint(accent)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(dataStore)
                .mossTypography()
                .tint(accent)
        }
    }
}
