# Moss 2.0 UI and Accumulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Moss into a refined native Mac focus app whose Today, completion feedback, and Growth Journal make long-term work visibly accumulate.

**Architecture:** Keep `DataStore` and the persisted database unchanged. Extend the pure `FocusAnalyticsSnapshot` projection with yearly, recent, monthly, and milestone outputs; derive an ephemeral `FocusCompletionReceipt` in `AppStore`; then render both through a compact design system shared by Today, Growth Journal, Timeline, and the app shell.

**Tech Stack:** Swift 6.2, SwiftUI, Charts, AppKit, macOS 14 SDK, direct `swiftc` build and behavior-check scripts.

---

### Task 1: Analytics projections and completion receipt

**Files:**
- Modify: `Tests/MossBehaviorCheck.swift`
- Modify: `Sources/Moss/FocusAnalytics.swift`

- [ ] **Step 1: Add failing analytics assertions**

Add fixed-calendar fixtures covering empty months, recent seven-day focus, current-year totals, milestone ordering, and a session that crosses the 200-hour achievement:

```swift
let accumulation = FocusAnalyticsSnapshot(
    sessions: [
        fixtureSession(title: "课业", date: date(2025, 12, 30), duration: 3_600, status: .completed),
        fixtureSession(title: "课业", date: date(2026, 1, 2), duration: 2 * 3_600, status: .completed),
        fixtureSession(title: "开发", date: date(2026, 3, 5), duration: 1_800, status: .completed)
    ],
    now: date(2026, 3, 8),
    calendar: calendar
)
precondition(accumulation.currentYearFocus == 9_000)
precondition(accumulation.recentFocus == 1_800)
precondition(accumulation.recentMonths.count == 12)
precondition(accumulation.recentMonths.suffix(3).map(\.duration) == [7_200, 0, 1_800])
```

Construct before/after snapshots around a threshold and assert `FocusCompletionReceipt.make` returns the session duration, task total, overall total, completion count, and newly unlocked achievement.

- [ ] **Step 2: Run the behavior check and verify RED**

Run: `./scripts/behavior-check.sh`

Expected: compilation fails because the new snapshot properties and receipt type do not exist.

- [ ] **Step 3: Implement deterministic projections**

Add these public values to `FocusAnalyticsSnapshot`:

```swift
let currentYearFocus: TimeInterval
let currentYearActiveDays: Int
let recentFocus: TimeInterval
let recentMonths: [FocusMonthRecord]
let latestUnlockedAchievement: Achievement?
let nextAchievement: Achievement?
```

Build twelve consecutive calendar-month records ending in `now`'s month, including zero-duration months. Use `[startOfToday - 6 days, tomorrow)` for recent focus and the calendar year interval for year values. Preserve the declaration order of achievements when choosing the next locked milestone.

Add:

```swift
struct FocusCompletionReceipt: Identifiable {
    let id: UUID
    let focusedDuration: TimeInterval
    let taskTitle: String
    let taskTotal: TimeInterval
    let overallTotal: TimeInterval
    let completionCount: Int
    let unlockedAchievement: Achievement?
    let nextAchievement: Achievement?

    static func make(
        focusedDuration: TimeInterval,
        taskTitle: String,
        before: FocusAnalyticsSnapshot,
        after: FocusAnalyticsSnapshot
    ) -> FocusCompletionReceipt
}
```

Determine the new achievement by comparing unlocked IDs before and after. Resolve `taskTotal` from the after snapshot's title metric.

- [ ] **Step 4: Verify GREEN and commit**

Run: `./scripts/behavior-check.sh && ./scripts/typecheck.sh`

Expected: all behavior labels print `pass`; typecheck exits 0.

Commit: `git commit -am "feat: derive accumulation history and completion receipts"`

### Task 2: Moss 2.0 visual foundation and shell

**Files:**
- Modify: `scripts/ui-regression-check.sh`
- Modify: `Sources/Moss/DesignSystem.swift`
- Modify: `Sources/Moss/Typography.swift`
- Modify: `Sources/Moss/MainView.swift`

- [ ] **Step 1: Add failing UI contracts**

Require the new semantic building blocks and copy:

```zsh
expect "Sources/Moss/DesignSystem.swift" "enum MossSurfaceKind"
expect "Sources/Moss/DesignSystem.swift" "struct MossPageHeader"
expect "Sources/Moss/DesignSystem.swift" "struct MossMetric"
expect "Sources/Moss/Typography.swift" "static func editorial"
expect "Sources/Moss/MainView.swift" 'case .insights: "成长志"'
expect "Sources/Moss/MainView.swift" ".tint(MossTheme.sage)"
```

- [ ] **Step 2: Run the contract check and verify RED**

Run: `./scripts/ui-regression-check.sh`

Expected: failure on `enum MossSurfaceKind`.

- [ ] **Step 3: Implement the shared system**

Create:

```swift
enum MossSurfaceKind { case standard, quiet, hero }

struct MossPageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing
}

struct MossMetric: View {
    let value: String
    let label: String
    var symbol: String?
    var tint: Color = MossTheme.sage
}
```

Extend `MossCard` with `kind`, using a gradient and stronger border only for `hero`, a low-contrast fill for `quiet`, and a subtle boundary for `standard`. Add `MossTypography.editorial` using the selected font when it is explicitly serif-like and the system serif design otherwise. Keep all existing initializers source-compatible.

Rename the navigation label to “成长志”, use the theme tint at the split-view root, and revise the idle sidebar footer to show the last-seven-day and all-time totals derived from `DataStore.sessions`.

- [ ] **Step 4: Verify and commit**

Run: `./scripts/ui-regression-check.sh && ./scripts/typecheck.sh`

Commit: `git commit -am "feat: establish Moss 2.0 visual language"`

### Task 3: Completion receipt behavior and presentation

**Files:**
- Modify: `Tests/MossBehaviorCheck.swift`
- Modify: `Sources/Moss/AppStore.swift`
- Modify: `Sources/Moss/MainView.swift`
- Create: `Sources/Moss/FocusCompletionView.swift`

- [ ] **Step 1: Add the failing completion-state assertion**

After `finishReview`, assert:

```swift
precondition(appStore.completionReceipt?.focusedDuration ?? 0 > 0)
precondition(appStore.completionReceipt?.taskTitle == lifecycleTask.title)
```

- [ ] **Step 2: Verify RED**

Run: `./scripts/behavior-check.sh`

Expected: compilation fails because `completionReceipt` does not exist.

- [ ] **Step 3: Publish the receipt from AppStore**

Add `@Published var completionReceipt: FocusCompletionReceipt?`. In `finishReview`, compute the `before` snapshot before mutating the session and the `after` snapshot afterward, then assign `FocusCompletionReceipt.make(...)`. Clear it after 4.8 seconds only if the receipt ID is still current.

Render `FocusCompletionView` from `MainView` as a top-trailing overlay. The card must show `+\(focusedDuration)`, task cumulative time, total cumulative time, and either the newly unlocked achievement or distance to the next milestone. Respect `accessibilityReduceMotion` and combine the receipt into one VoiceOver announcement.

- [ ] **Step 4: Verify and commit**

Run: `./scripts/behavior-check.sh && ./scripts/typecheck.sh`

Commit: `git add Sources/Moss/{AppStore,MainView,FocusCompletionView}.swift Tests/MossBehaviorCheck.swift && git commit -m "feat: show a receipt for every completed focus session"`

### Task 4: Today as continuation of a body of work

**Files:**
- Modify: `scripts/ui-regression-check.sh`
- Modify: `Sources/Moss/TodayView.swift`

- [ ] **Step 1: Add failing Today contracts**

Require the new continuity copy and analytics context:

```zsh
expect "Sources/Moss/TodayView.swift" "加入"
expect "Sources/Moss/TodayView.swift" "全部积累"
expect "Sources/Moss/TodayView.swift" "当前领域"
expect "Sources/Moss/TodayView.swift" "MossCard(kind: .hero"
```

- [ ] **Step 2: Verify RED**

Run: `./scripts/ui-regression-check.sh`

Expected: failure on the first new copy.

- [ ] **Step 3: Recompose the hero**

Create one local `FocusAnalyticsSnapshot` from `dataStore.sessions`. When idle, the largest sentence is “把今天的一小段，加入 \(totalFocus) 里”; show today duration, all-time duration, active days, and next milestone underneath. Keep the preferred task as the primary action and five-minute ignition as secondary.

When active, keep the timer largest and show the current title's cumulative total as “当前领域”. Preserve existing pause, interruption, end, review, break, keyboard, and accessibility behavior. Restyle task/project rows and supporting cards with shared surfaces without changing task actions.

- [ ] **Step 4: Verify and commit**

Run: `./scripts/ui-regression-check.sh && ./scripts/typecheck.sh`

Commit: `git commit -am "feat: connect Today to long-term focus accumulation"`

### Task 5: Growth Journal narrative

**Files:**
- Modify: `scripts/ui-regression-check.sh`
- Modify: `Sources/Moss/InsightsView.swift`
- Modify: `Sources/Moss/FocusHeatmapView.swift`
- Modify: `Sources/Moss/TitleDetailView.swift`

- [ ] **Step 1: Add failing Growth Journal contracts**

```zsh
expect "Sources/Moss/InsightsView.swift" 'Text("你的投入，正在成为可以回望的作品。")'
expect "Sources/Moss/InsightsView.swift" 'Text("积累编年史")'
expect "Sources/Moss/InsightsView.swift" 'Text("成长证据")'
expect "Sources/Moss/InsightsView.swift" "analytics.recentMonths"
expect "Sources/Moss/InsightsView.swift" "MonthlyChronicleCard"
```

- [ ] **Step 2: Verify RED**

Run: `./scripts/ui-regression-check.sh`

- [ ] **Step 3: Rebuild the page hierarchy**

Replace the level-first hero with:

1. an editorial statement using all-time total;
2. a dark/tonal yearly seal with current-year focus and progress to the next achievement;
3. a twelve-month `Chart` card with evidence callouts;
4. the existing island map, simplified to quieter gradients and fewer simultaneous shadows;
5. an unlocked-first evidence row with dates, followed by the next milestone;
6. personal records, ranking, and heatmap.

Keep `TitleDetailView` navigation and make its heading use the shared page header and editorial typography. Keep heatmap thresholds and data behavior, only update surfaces and summary hierarchy.

- [ ] **Step 4: Verify and commit**

Run: `./scripts/ui-regression-check.sh && ./scripts/typecheck.sh && ./scripts/build-app.sh`

Commit: `git commit -am "feat: turn achievements into a growth journal"`

### Task 6: Timeline polish and full acceptance

**Files:**
- Modify: `Sources/Moss/TimelinePage.swift`
- Modify: `README.md`
- Test: `scripts/ui-regression-check.sh`, `scripts/typecheck.sh`, `scripts/behavior-check.sh`, `scripts/build-app.sh`

- [ ] **Step 1: Apply shared hierarchy without behavior changes**

Use `MossPageHeader`, `MossMetric`, and surface kinds for Timeline's header, filter panel, summary strip, chart, and day groups. Keep range persistence, filters, chart calculations, and title-detail navigation unchanged.

- [ ] **Step 2: Update product documentation**

Describe “成长志”, completion receipts, accumulation chronicle, and the principle that all derived growth evidence remains local and requires no data migration.

- [ ] **Step 3: Run the full automated suite**

Run:

```zsh
./scripts/ui-regression-check.sh
./scripts/typecheck.sh
./scripts/behavior-check.sh
./scripts/build-app.sh
```

Expected: UI contract message and all 12+ behavior labels print `pass`; remaining commands exit 0.

- [ ] **Step 4: Perform real-app visual QA**

Launch the freshly built `dist/Moss.app` and inspect Today, Timeline, Growth Journal, a title detail sheet, dark/light appearance, narrow 900×620 layout, and reduced-motion semantics. Verify no truncation, system-blue selection, overlapping controls, or inaccessible icon-only actions.

- [ ] **Step 5: Commit**

Run: `git add README.md Sources/Moss/TimelinePage.swift && git commit -m "feat: complete Moss 2.0 workspace polish"`
