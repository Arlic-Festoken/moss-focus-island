# Moss Native UI and Quiet Launch Design

## Intent

Moss should feel like a calm macOS companion rather than a dashboard that competes for attention. It launches without stealing focus, stays available from the menu bar and focus island, and opens a full-size workspace only when the user explicitly asks for it.

## Visual direction

- Keep the paper-like theme palette and use its accent only for the active timer, selected state, and primary action.
- Let the sidebar, toolbar, menus, settings form, and window chrome use native macOS material and spacing.
- Keep cards for information groups, but remove card-like treatment from navigation and dense utility controls.
- Replace fixed two-column dashboard rows with adaptive horizontal-or-stacked layouts so the same hierarchy works from the minimum window size through wide displays.

## Window and launch behavior

- The primary scene remains a singleton `Window` with the stable scene id `main`; it is opened from the menu bar, island, and `AppStore.openMainWindow()`.
- `MainView` owns the 900×620 minimum content size. The window helper may recover an invalid/off-screen restored frame, but must not overwrite SwiftUI's scene identifier.
- A launch preference defaults to quiet. The initial main window is ordered out after the menu bar extra is ready, so it does not activate or cover the user's work. Opening Moss manually makes the existing window key and front.
- Settings exposes the launch preference and explains that it applies on the next launch.

## Workspace structure and responsive content

- The app shell has a native sidebar and a toolbar with global New Task, New Project, and Start Last Task actions.
- Today retains its greeting and focus state, but its task/insight and timeline/feedback bands use `ViewThatFits` to become vertical stacks below their safe width.
- Task rows have explicit start, details, and more-actions controls. Their menu start actions and visible play button share the same disabled state. Double-click is removed as the only path to detail.
- Month cells in Timeline are accessible buttons. Selecting a day switches to the day view and shows that day's session detail.

## Interaction and accessibility

- Typography changes preserve view identity, sheets, scroll position, and focus. The selected font is applied through the existing font helper rather than resetting the entire scene.
- Theme tokens include a readable primary-action foreground so light accents do not force low-contrast white text.
- Custom font/theme/island selectors expose labels, values, selected traits, and keyboard focus.
- During the warm-up phase, Cancel Start always discards the session; finishing is unavailable until a real focus minute exists. Menu bar start wording reflects the actual last-task behavior.
- The focus island has an explicit, keyboard-accessible button to open focus controls; hover remains a convenience, not the only access path.

## Acceptance criteria

1. Moss starts in the background and leaves the user on their current app; the menu bar extra is available.
2. Opening Moss yields one visible main window of at least 900×620, even after a bad restored frame.
3. Toolbar actions, task controls, focus controls, settings selectors, and timeline days can be operated without hidden double-click or hover-only paths.
4. Today stacks cleanly at the minimum window width and keeps its two-column balance on wide windows.
5. Font and theme changes do not dismiss a sheet or reset the active section.
6. Typecheck, app packaging, UI regression checks, and a background launch smoke test all pass.
