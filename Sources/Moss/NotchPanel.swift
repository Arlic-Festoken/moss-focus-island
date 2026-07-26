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
final class NotchPanelController: ObservableObject {
    static let shared = NotchPanelController()

    @Published private(set) var hasNotch = false

    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var presentation: IslandPanelPresentation = .idle
    private var currentScreenID: String?
    private var dragState: DragState?

    private struct DragState {
        var mouseOrigin: CGPoint
        var panelOrigin: CGPoint
    }

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

        reposition(animated: false)
        panel?.orderFrontRegardless()

        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reposition(animated: false) }
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setPresentation(_ newPresentation: IslandPanelPresentation, animated: Bool = true) {
        guard presentation != newPresentation else { return }
        presentation = newPresentation
        guard dragState == nil else { return }
        reposition(animated: animated)
    }

    func reposition(animated: Bool = true) {
        guard let panel, let screen = preferredScreen else { return }
        let defaults = UserDefaults.standard
        let placement = IslandPlacement(
            rawValue: defaults.string(forKey: "islandPlacement") ?? ""
        ) ?? .topCenter
        let geometry = screen.geometry
        let panelHasNotch = geometry.hasNotch && placement == .topCenter
        let size = IslandPanelGeometry.size(
            for: presentation,
            hasNotch: panelHasNotch,
            placement: placement
        )
        let offset = CGSize(
            width: defaults.double(forKey: "islandOffsetX"),
            height: defaults.double(forKey: "islandOffsetY")
        )
        let target = IslandPanelGeometry.frame(
            placement: placement,
            screen: geometry,
            size: size,
            offset: offset
        )
        currentScreenID = screen.displayID
        defaults.set(currentScreenID, forKey: "islandDisplayID")
        hasNotch = panelHasNotch
        let shouldAnimate = animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(target, display: true, animate: shouldAnimate)
    }

    func beginDrag(at mouseLocation: CGPoint = NSEvent.mouseLocation) {
        guard let panel else { return }
        dragState = DragState(
            mouseOrigin: mouseLocation,
            panelOrigin: panel.frame.origin
        )
    }

    func updateDrag(at mouseLocation: CGPoint = NSEvent.mouseLocation) {
        guard let panel, let dragState else { return }
        let delta = CGPoint(
            x: mouseLocation.x - dragState.mouseOrigin.x,
            y: mouseLocation.y - dragState.mouseOrigin.y
        )
        let proposed = CGRect(
            origin: CGPoint(
                x: dragState.panelOrigin.x + delta.x,
                y: dragState.panelOrigin.y + delta.y
            ),
            size: panel.frame.size
        )
        let targetScreen = screen(containing: mouseLocation)
            ?? screen(containing: proposed.center)
            ?? preferredScreen
        guard let targetScreen else { return }
        let placement = currentPlacement
        let clamped = IslandPanelGeometry.clamped(
            proposed,
            to: IslandPanelGeometry.movementBounds(
                for: placement,
                screen: targetScreen.geometry
            )
        )
        currentScreenID = targetScreen.displayID
        hasNotch = targetScreen.geometry.hasNotch && placement == .topCenter
        panel.setFrame(clamped, display: true, animate: false)
    }

    func endDrag() {
        defer { dragState = nil }
        guard let panel else { return }
        let screen = screen(containing: panel.frame.center)
            ?? screen(withID: currentScreenID)
            ?? preferredScreen
        guard let screen else { return }
        let placement = currentPlacement
        let clamped = IslandPanelGeometry.clamped(
            panel.frame,
            to: IslandPanelGeometry.movementBounds(
                for: placement,
                screen: screen.geometry
            )
        )
        panel.setFrame(clamped, display: true, animate: false)
        let offset = IslandPanelGeometry.offset(
            for: clamped,
            placement: placement,
            screen: screen.geometry
        )
        let defaults = UserDefaults.standard
        defaults.set(Double(offset.width), forKey: "islandOffsetX")
        defaults.set(Double(offset.height), forKey: "islandOffsetY")
        defaults.set(screen.displayID, forKey: "islandDisplayID")
        currentScreenID = screen.displayID
    }

    func resetPosition() {
        let defaults = UserDefaults.standard
        defaults.set(0.0, forKey: "islandOffsetX")
        defaults.set(0.0, forKey: "islandOffsetY")
        defaults.removeObject(forKey: "islandDisplayID")
        currentScreenID = nil
        reposition(animated: true)
    }

    private var currentPlacement: IslandPlacement {
        IslandPlacement(
            rawValue: UserDefaults.standard.string(forKey: "islandPlacement") ?? ""
        ) ?? .topCenter
    }

    private var preferredScreen: NSScreen? {
        screen(withID: currentScreenID)
            ?? screen(withID: UserDefaults.standard.string(forKey: "islandDisplayID"))
            ?? panel.flatMap { screen(containing: $0.frame.center) }
            ?? screen(containing: NSEvent.mouseLocation)
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(point) })
    }

    private func screen(withID id: String?) -> NSScreen? {
        guard let id else { return nil }
        return NSScreen.screens.first(where: { $0.displayID == id })
    }
}

private final class MossPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private extension NSScreen {
    var displayID: String? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .stringValue
    }

    var geometry: IslandScreenGeometry {
        IslandScreenGeometry(
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaTop: safeAreaInsets.top,
            displayID: displayID
        )
    }
}

struct NotchIslandView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var panelController = NotchPanelController.shared
    @State private var hovering = false
    @State private var isDragging = false
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue
    @AppStorage("islandPlacement") private var islandPlacement = IslandPlacement.topCenter.rawValue

    private var hasNotch: Bool {
        panelController.hasNotch
    }

    private var presentation: IslandPanelPresentation {
        if store.phase == .idle { return .idle }
        if hovering || store.isIslandExpanded { return .expanded }
        return .compact
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
            panelController.reposition(animated: true)
        }
        .onAppear {
            panelController.setPresentation(presentation, animated: false)
        }
        .onChange(of: presentation) { _, newValue in
            panelController.setPresentation(newValue, animated: !isDragging)
        }
        .overlay(alignment: .top) {
            dragHandle
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

    private var islandDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { _ in
                if !isDragging {
                    isDragging = true
                    panelController.beginDrag()
                }
                panelController.updateDrag()
            }
            .onEnded { _ in
                panelController.endDrag()
                isDragging = false
            }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.white.opacity(0.36))
            .frame(width: 30, height: 3)
            .frame(width: 70, height: 12)
            .contentShape(Rectangle())
            .gesture(islandDragGesture)
            .help("拖动专注岛")
    }

    private var idleIsland: some View {
        Button {
            store.openMainWindow()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MossTheme.mint)
                Text(store.transientNotice?.message ?? "今日 \(store.todayCompletedCount) 段")
                    .font(MossTypography.font(11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.93), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("打开 Moss；拖动可移动专注岛")
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
                            .font(MossTypography.font(13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }

                if hasNotch {
                    Color.clear.frame(width: 118, height: 34)
                }

                islandLobe {
                    HStack(spacing: 7) {
                        Text(
                            store.transientNotice?.message
                                ?? (store.phase == .breakTime ? BreakPrompt.current : store.currentTaskTitle)
                        )
                            .lineLimit(1)
                        if store.phase != .breakTime {
                            Text("· \(store.todayCompletedCount)")
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .font(MossTypography.font(11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开专注控制")
        .help("打开专注控制；拖动可移动专注岛")
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
                    .font(MossTypography.font(10, weight: .semibold))
                    .foregroundStyle(phaseTint)
                Text(
                    store.transientNotice?.message
                        ?? (store.phase == .breakTime ? BreakPrompt.current : store.currentTaskTitle)
                )
                    .font(MossTypography.font(12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 5)

            Text(store.displayTime.clockString)
                .font(MossTypography.font(20, weight: .bold))
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
                    islandButton("checkmark", tint: MossTheme.mint) { store.presentReview() }
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
