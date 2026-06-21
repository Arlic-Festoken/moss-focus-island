import AppKit
import SwiftUI

enum IslandPlacement: String, CaseIterable, Identifiable {
    case topCenter
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topCenter: "顶部居中"
        case .topLeading: "左上角"
        case .topTrailing: "右上角"
        case .bottomLeading: "左下角"
        case .bottomTrailing: "右下角"
        }
    }

    var icon: String {
        switch self {
        case .topCenter: "rectangle.topthird.inset.filled"
        case .topLeading: "arrow.up.left"
        case .topTrailing: "arrow.up.right"
        case .bottomLeading: "arrow.down.left"
        case .bottomTrailing: "arrow.down.right"
        }
    }
}

@MainActor
final class NotchPanelController {
    static let shared = NotchPanelController()

    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?

    private init() {}

    func show(store: AppStore) {
        guard UserDefaults.standard.object(forKey: "showNotchIsland") as? Bool ?? true else {
            return
        }

        if panel == nil {
            let panel = MossPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.identifier = NSUserInterfaceItemIdentifier("moss.notch.panel")
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.hidesOnDeactivate = false
            panel.isMovable = false
            panel.isReleasedWhenClosed = false
            panel.contentViewController = NSHostingController(
                rootView: NotchIslandView()
                    .environmentObject(store)
            )
            self.panel = panel
        }

        reposition()
        panel?.orderFrontRegardless()

        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reposition() }
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func reposition() {
        guard let panel, let screen = preferredScreen else { return }
        let defaults = UserDefaults.standard
        let placement = IslandPlacement(
            rawValue: defaults.string(forKey: "islandPlacement") ?? ""
        ) ?? .topCenter
        let hasNotch = screen.safeAreaInsets.top > 0 && placement == .topCenter
        let width: CGFloat = hasNotch ? 520 : 390
        let height: CGFloat = 74
        let safeFrame = placement == .topCenter ? screen.frame : screen.visibleFrame
        let margin: CGFloat = 10
        var x: CGFloat
        var y: CGFloat

        switch placement {
        case .topCenter:
            x = screen.frame.midX - width / 2
            y = screen.frame.maxY - height - (hasNotch ? 1 : 7)
        case .topLeading:
            x = safeFrame.minX + margin
            y = safeFrame.maxY - height - margin
        case .topTrailing:
            x = safeFrame.maxX - width - margin
            y = safeFrame.maxY - height - margin
        case .bottomLeading:
            x = safeFrame.minX + margin
            y = safeFrame.minY + margin
        case .bottomTrailing:
            x = safeFrame.maxX - width - margin
            y = safeFrame.minY + margin
        }

        x += CGFloat(defaults.double(forKey: "islandOffsetX"))
        y += CGFloat(defaults.double(forKey: "islandOffsetY"))
        x = min(max(x, screen.frame.minX), screen.frame.maxX - width)
        y = min(max(y, screen.frame.minY), screen.frame.maxY - height)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: true)
    }

    private var preferredScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private final class MossPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct NotchIslandView: View {
    @EnvironmentObject private var store: AppStore
    @State private var hovering = false
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue
    @AppStorage("islandPlacement") private var islandPlacement = IslandPlacement.topCenter.rawValue

    private var hasNotch: Bool {
        (NSScreen.main?.safeAreaInsets.top ?? 0 > 0)
            && islandPlacement == IslandPlacement.topCenter.rawValue
    }

    var body: some View {
        Group {
            if store.phase == .idle {
                idleIsland
            } else if hovering || store.isIslandExpanded {
                expandedIsland
            } else {
                compactIsland
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .mossTypography()
        .tint(MossColorTheme(rawValue: colorTheme)?.accent ?? MossTheme.sage)
        .onChange(of: islandPlacement) { _, _ in
            NotchPanelController.shared.reposition()
        }
        .animation(.smooth(duration: 0.28), value: hovering)
        .animation(.smooth(duration: 0.28), value: store.phase)
        .onHover { inside in
            hovering = inside
            store.isIslandExpanded = inside
        }
        .popover(isPresented: $store.interruptionNeedsReason) {
            InterruptionReasonPicker()
                .environmentObject(store)
        }
    }

    private var idleIsland: some View {
        Button {
            store.openMainWindow()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MossTheme.mint)
                Text("今日 \(store.todayCompletedCount) 段")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.93), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, hasNotch ? 7 : 0)
    }

    private var compactIsland: some View {
        Button {
            store.isIslandExpanded = true
        } label: {
            HStack(spacing: 0) {
                islandLobe {
                    HStack(spacing: 8) {
                        ProgressRing(progress: store.progress, lineWidth: 3, tint: phaseTint)
                            .frame(width: 20, height: 20)
                        Text(store.displayTime.clockString)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }

                if hasNotch {
                    Color.clear.frame(width: 118, height: 34)
                }

                islandLobe {
                    HStack(spacing: 7) {
                        Text(store.phase == .breakTime ? BreakPrompt.current : store.currentTaskTitle)
                            .lineLimit(1)
                        if store.phase != .breakTime {
                            Text("· \(store.todayCompletedCount)")
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开专注控制")
        .help("打开专注控制")
        .padding(.top, hasNotch ? 2 : 0)
    }

    private var expandedIsland: some View {
        HStack(spacing: 14) {
            ProgressRing(progress: store.progress, lineWidth: 4, tint: phaseTint)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: store.phase == .paused ? "pause.fill" : store.phase == .breakTime ? "cup.and.saucer.fill" : "leaf.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(phaseTint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(phaseTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(phaseTint)
                Text(store.phase == .breakTime ? BreakPrompt.current : store.currentTaskTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 5)

            Text(store.displayTime.clockString)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                if store.phase == .preparing {
                    islandButton("xmark", tint: MossTheme.brick) { store.cancelStart() }
                } else if store.phase == .focusing {
                    islandButton("pause.fill") { store.pause() }
                    islandButton("arrow.up.right") { store.beginOrReturnFromInterruption() }
                    islandButton("stop.fill", tint: MossTheme.brick) { store.requestEnd() }
                } else if store.phase == .paused {
                    islandButton("play.fill", tint: MossTheme.mint) { store.resume() }
                    islandButton("stop.fill", tint: MossTheme.brick) { store.requestEnd() }
                } else if store.phase == .breakTime {
                    islandButton("forward.end.fill", tint: MossTheme.apricot) { store.skipBreak() }
                } else {
                    islandButton("checkmark", tint: MossTheme.mint) { store.isReviewPresented = true }
                }
                islandButton("chevron.up") { store.isIslandExpanded = false }
            }
        }
        .padding(.horizontal, 15)
        .frame(width: 470, height: 58)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.94))
                .shadow(color: .black.opacity(0.24), radius: 13, y: 7)
        )
        .padding(.top, hasNotch ? 2 : 0)
    }

    private func islandLobe<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(Color.black.opacity(0.94), in: Capsule())
    }

    private func islandButton(_ symbol: String, tint: Color = MossTheme.sage, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.68), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityName(for: symbol))
    }

    private func accessibilityName(for symbol: String) -> String {
        switch symbol {
        case "pause.fill": "暂停专注"
        case "play.fill": "继续专注"
        case "arrow.up.right": "记录打断"
        case "stop.fill": "结束专注"
        case "forward.end.fill": "结束休息"
        case "checkmark": "完成记录"
        case "xmark": "取消开始"
        case "chevron.up": "收起专注控制"
        default: "专注操作"
        }
    }

    private var phaseTint: Color {
        if store.phase == .breakTime { return MossTheme.apricot }
        if store.phase == .preparing { return MossTheme.apricot }
        guard store.timerActivity.countsDown else { return MossTheme.mint }
        if store.remaining <= 60 { return MossTheme.brick }
        if store.remaining <= 300 { return MossTheme.apricot }
        return MossTheme.mint
    }

    private var phaseTitle: String {
        switch store.phase {
        case .preparing: "进入状态"
        case .focusing: "深度专注中"
        case .paused: "暂停"
        case .breakTime: "休息"
        case .awaitingReview: "完成这一段"
        case .idle: "未开始"
        }
    }
}
