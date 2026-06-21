# Moss Native UI and Quiet Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Moss launch quietly and deliver a native, responsive, keyboard-accessible macOS focus workspace.

**Architecture:** Keep the current SwiftUI scene and `AppStore` as the state boundary. Window recovery stays in `WindowConfigurator`; the shell owns global toolbar actions, while pages own presentation state. A small shell regression script validates the durable UI contracts alongside the existing compiler/package scripts.

**Tech Stack:** Swift 5, SwiftUI, AppKit, macOS 14 SDK, direct `swiftc` build scripts.

---

### Task 1: Quiet singleton window and regression guard

**Files:**
- Create: `scripts/ui-regression-check.sh`
- Modify: `Sources/Moss/MossApp.swift`, `MainView.swift`, `WindowConfigurator.swift`, `AppStore.swift`, `SettingsView.swift`

- [ ] **Step 1: Write the failing window contract check**

```zsh
expect "Sources/Moss/MossApp.swift" "@NSApplicationDelegateAdaptor(MossAppDelegate.self)"
expect "Sources/Moss/MainView.swift" ".frame(minWidth: 900, minHeight: 620)"
reject "Sources/Moss/WindowConfigurator.swift" "window.identifier ="
expect "Sources/Moss/SettingsView.swift" "启动后仅在菜单栏驻留"
```

- [ ] **Step 2: Run `zsh scripts/ui-regression-check.sh`**

Expected: it fails because the quiet-launch contract does not exist.

- [ ] **Step 3: Implement the minimum behavior**

```swift
final class MossAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard UserDefaults.standard.object(forKey: "launchSilently") as? Bool ?? true else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NSApp.windows.filter { $0.title == "Moss · 专注岛" }.forEach { $0.orderOut(nil) }
        }
    }
}
```

Attach the delegate to `MossApp`, add the direct minimum frame to `MainView`, remove only the window identifier mutation, add the Settings toggle, and keep `AppStore.openMainWindow()` as the explicit foreground path.

- [ ] **Step 4: Verify**

Run: `zsh scripts/ui-regression-check.sh && ./scripts/typecheck.sh && ./scripts/build-app.sh`

Expected: all exit with code 0.

- [ ] **Step 5: Commit**

Run: `git add scripts/ui-regression-check.sh Sources/Moss/{MossApp,MainView,WindowConfigurator,AppStore,SettingsView}.swift && git commit -m "fix: launch Moss quietly with stable window recovery"`

### Task 2: Native shell, adaptive dashboard, and readable themes

**Files:**
- Modify: `Sources/Moss/MainView.swift`, `TodayView.swift`, `DesignSystem.swift`, `Typography.swift`
- Test: `scripts/ui-regression-check.sh`

- [ ] **Step 1: Extend the failing contract**

```zsh
expect "Sources/Moss/MainView.swift" ".toolbar"
expect "Sources/Moss/TodayView.swift" "ViewThatFits(in: .horizontal)"
expect "Sources/Moss/DesignSystem.swift" "var accentForeground"
reject "Sources/Moss/Typography.swift" ".id(\"\\(fontTheme)-\\(fontSize)\")"
```

- [ ] **Step 2: Run the check and observe the missing toolbar contract**

Run: `zsh scripts/ui-regression-check.sh`

- [ ] **Step 3: Implement the shell and compact layout**

```swift
ViewThatFits(in: .horizontal) {
    HStack(alignment: .top, spacing: 18) { primaryCard.frame(minWidth: 440); supportingCard.frame(width: 300) }
    VStack(alignment: .leading, spacing: 18) { primaryCard; supportingCard }
}
```

Put New Task, New Project, and Start Last Task in the main toolbar. Keep themed paper for detail content but return the sidebar to native material. Add `accentForeground` and use it in the primary button style. Remove the typography root identity reset.

- [ ] **Step 4: Verify**

Run: `zsh scripts/ui-regression-check.sh && ./scripts/typecheck.sh`

- [ ] **Step 5: Commit**

Run: `git add Sources/Moss/{MainView,TodayView,DesignSystem,Typography}.swift scripts/ui-regression-check.sh && git commit -m "feat: polish native workspace layout"`

### Task 3: Discoverable focus controls and task actions

**Files:**
- Modify: `Sources/Moss/AppStore.swift`, `TodayView.swift`, `MenuBarView.swift`, `NotchPanel.swift`, `SettingsView.swift`
- Test: `scripts/ui-regression-check.sh`

- [ ] **Step 1: Extend the failing interaction contract**

```zsh
expect "Sources/Moss/AppStore.swift" "func cancelStart()"
expect "Sources/Moss/TodayView.swift" "查看记录"
reject "Sources/Moss/TodayView.swift" ".onTapGesture(count: 2)"
expect "Sources/Moss/MenuBarView.swift" "store.startLastTask()"
expect "Sources/Moss/NotchPanel.swift" "打开专注控制"
```

- [ ] **Step 2: Run the check and observe the missing cancellation contract**

Run: `zsh scripts/ui-regression-check.sh`

- [ ] **Step 3: Implement explicit, consistent controls**

```swift
func cancelStart() {
    guard phase == .preparing, let sessionID = run?.sessionID else { return }
    dataStore?.removeSession(id: sessionID)
    clearToIdle()
    showTransient("已取消，本次未计时")
}
```

Expose Cancel Start only in warm-up, make task menu starts and the visible play button share the same idle condition, replace double-click detail with labelled controls, use `startLastTask()` in the menu-bar idle action, and add an explicit island control affordance plus the end shortcut in Settings.

- [ ] **Step 4: Verify**

Run: `zsh scripts/ui-regression-check.sh && ./scripts/typecheck.sh`

- [ ] **Step 5: Commit**

Run: `git add Sources/Moss/{AppStore,TodayView,MenuBarView,NotchPanel,SettingsView}.swift scripts/ui-regression-check.sh && git commit -m "feat: clarify focus controls and task actions"`

### Task 4: Timeline and settings selection semantics

**Files:**
- Modify: `Sources/Moss/TimelinePage.swift`, `SettingsView.swift`
- Test: `scripts/ui-regression-check.sh`

- [ ] **Step 1: Extend the failing navigation and accessibility contract**

```zsh
expect "Sources/Moss/TimelinePage.swift" "selectedDate"
expect "Sources/Moss/TimelinePage.swift" "range = .day"
expect "Sources/Moss/SettingsView.swift" ".accessibilityAddTraits(.isSelected)"
```

- [ ] **Step 2: Run `zsh scripts/ui-regression-check.sh` and observe failure**

Expected: missing `selectedDate`.

- [ ] **Step 3: Implement reachable dates and semantic option tiles**

```swift
Button {
    selectedDate = day
    range = .day
} label: { dayCell(day) }
.buttonStyle(.plain)
.accessibilityLabel(day.formatted(date: .complete, time: .omitted))
```

Dim adjacent-month cells and make each month day an accessible button. Add selected traits and values to the existing visual theme/font/island picker tiles.

- [ ] **Step 4: Verify**

Run: `zsh scripts/ui-regression-check.sh && ./scripts/typecheck.sh && ./scripts/build-app.sh`

- [ ] **Step 5: Commit**

Run: `git add Sources/Moss/{TimelinePage,SettingsView}.swift scripts/ui-regression-check.sh && git commit -m "feat: improve timeline and settings accessibility"`

### Task 5: Background visual smoke test

**Files:**
- Test: `scripts/ui-regression-check.sh`, `scripts/typecheck.sh`, `scripts/build-app.sh`

- [ ] **Step 1: Build an isolated QA app**

Run: `./scripts/build-app.sh && rm -rf /tmp/Moss-UI-QA.app && ditto dist/Moss.app /tmp/Moss-UI-QA.app`

- [ ] **Step 2: Start without focus stealing**

Run: `pkill -x Moss 2>/dev/null || true; open -gj /tmp/Moss-UI-QA.app; sleep 2`

Expected: Moss runs while the current foreground app remains unchanged.

- [ ] **Step 3: Check UI and clean up**

Run: `zsh scripts/ui-regression-check.sh && ./scripts/typecheck.sh && ./scripts/build-app.sh && pkill -x Moss 2>/dev/null || true`

Expected: all commands exit 0 and no foreground Moss process remains.
