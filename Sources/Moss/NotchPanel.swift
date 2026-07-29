import AppKit
import QuartzCore
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
    @Published private(set) var notchGapWidth = IslandPanelGeometry.minimumNotchGapWidth
    @Published private(set) var isVisible = false

    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var presentation: IslandPanelPresentation = .idle
    private var currentScreenID: String?
    private var isDragging = false

    private init() {}

    func show(store: AppStore) {
        guard UserDefaults.standard.object(forKey: "showNotchIsland") as? Bool ?? true else {
            isVisible = false
            return
        }
        guard let dataStore = store.dataStore else {
            isVisible = false
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
            panel.isMovable = true
            panel.isMovableByWindowBackground = false
            panel.isReleasedWhenClosed = false
            panel.contentViewController = NSHostingController(
                rootView: NotchIslandView(dataStore: dataStore)
                    .environmentObject(store)
            )
            self.panel = panel
        }

        reposition(animated: false)
        panel?.orderFrontRegardless()
        isVisible = true

        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reposition(animated: false)
                }
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func setVisible(_ visible: Bool, store: AppStore) {
        UserDefaults.standard.set(visible, forKey: "showNotchIsland")
        if visible {
            show(store: store)
        } else {
            hide()
        }
    }

    func setPresentation(_ newPresentation: IslandPanelPresentation, animated: Bool = true) {
        guard presentation != newPresentation else { return }
        presentation = newPresentation
        guard !isDragging else { return }
        reposition(animated: animated)
    }

    func reposition(animated: Bool = true) {
        guard let panel, let screen = preferredScreen else { return }
        let defaults = UserDefaults.standard
        let placement = IslandPlacement(
            rawValue: defaults.string(forKey: "islandPlacement") ?? ""
        ) ?? .topCenter
        let geometry = screen.geometry
        let integratesWithNotch = geometry.hasNotch
            && placement == .topCenter
            && presentation == .compact
        let avoidsNotch = geometry.hasNotch
            && placement == .topCenter
            && !integratesWithNotch
        let size = IslandPanelGeometry.size(
            for: presentation,
            hasNotch: integratesWithNotch,
            placement: placement,
            notchGapWidth: geometry.notchGapWidth
        )
        let offset = CGSize(
            width: defaults.double(forKey: "islandOffsetX"),
            height: defaults.double(forKey: "islandOffsetY")
        )
        let target = IslandPanelGeometry.frame(
            placement: placement,
            screen: geometry,
            size: size,
            offset: offset,
            avoidsNotch: avoidsNotch
        )
        currentScreenID = screen.displayID
        defaults.set(currentScreenID, forKey: "islandDisplayID")
        hasNotch = integratesWithNotch
        notchGapWidth = geometry.notchGapWidth
        let shouldAnimate = animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.34
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.22,
                    0.72,
                    0.28,
                    1
                )
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true, animate: false)
        }
    }

    func performNativeDrag(with event: NSEvent) {
        guard let panel else { return }
        isDragging = true
        panel.performDrag(with: event)
        isDragging = false
        settleAfterDrag()
    }

    private func settleAfterDrag() {
        guard let panel else { return }
        let screen = screen(containing: panel.frame.center)
            ?? screen(withID: currentScreenID)
            ?? preferredScreen
        guard let screen else { return }
        let placement = currentPlacement
        let geometry = screen.geometry
        let integratesWithNotch = geometry.hasNotch
            && placement == .topCenter
            && presentation == .compact
        let avoidsNotch = geometry.hasNotch
            && placement == .topCenter
            && !integratesWithNotch
        let size = IslandPanelGeometry.size(
            for: presentation,
            hasNotch: integratesWithNotch,
            placement: placement,
            notchGapWidth: geometry.notchGapWidth
        )
        let proposed = CGRect(
            x: panel.frame.minX,
            y: panel.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        let clamped = IslandPanelGeometry.clamped(
            proposed,
            to: IslandPanelGeometry.movementBounds(
                for: placement,
                screen: geometry,
                avoidsNotch: avoidsNotch
            )
        )
        panel.setFrame(clamped, display: true, animate: false)
        let offset = IslandPanelGeometry.offset(
            for: clamped,
            placement: placement,
            screen: geometry,
            avoidsNotch: avoidsNotch
        )
        let defaults = UserDefaults.standard
        defaults.set(Double(offset.width), forKey: "islandOffsetX")
        defaults.set(Double(offset.height), forKey: "islandOffsetY")
        defaults.set(screen.displayID, forKey: "islandDisplayID")
        currentScreenID = screen.displayID
        hasNotch = integratesWithNotch
        notchGapWidth = geometry.notchGapWidth
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
        let notchWidth: CGFloat
        if let leftArea = auxiliaryTopLeftArea,
           let rightArea = auxiliaryTopRightArea {
            notchWidth = max(0, rightArea.minX - leftArea.maxX)
        } else {
            notchWidth = 0
        }
        return IslandScreenGeometry(
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaTop: safeAreaInsets.top,
            notchWidth: notchWidth,
            displayID: displayID
        )
    }
}

struct NotchIslandView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var dataStore: DataStore
    @ObservedObject private var panelController = NotchPanelController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var launcherExpanded = false
    @State private var selectedTaskID: FocusTask.ID?
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue
    @AppStorage("islandPlacement") private var islandPlacement = IslandPlacement.topCenter.rawValue

    init(dataStore: DataStore) {
        _dataStore = ObservedObject(wrappedValue: dataStore)
    }

    private var hasNotch: Bool {
        panelController.hasNotch
    }

    private var presentation: IslandPanelPresentation {
        if store.phase == .idle {
            return launcherExpanded ? .launcher : .idle
        }
        if hovering || store.isIslandExpanded { return .expanded }
        return .compact
    }

    private var preferredTask: FocusTask? {
        dataStore.preferredStartTask
    }

    private var selectedTask: FocusTask? {
        if let selectedTaskID,
           let task = dataStore.startableTasks.first(where: { $0.id == selectedTaskID }) {
            return task
        }
        return preferredTask
    }

    var body: some View {
        Group {
            if store.phase == .idle {
                if launcherExpanded {
                    taskLauncher
                        .transition(islandTransition)
                } else {
                    idleIsland
                        .transition(islandTransition)
                }
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
            panelController.setPresentation(newValue, animated: true)
        }
        .onChange(of: store.phase) { _, newPhase in
            if newPhase != .idle {
                setLauncherExpanded(false)
            }
        }
        .overlay(alignment: .top) {
            dragHandle
        }
        .animation(.smooth(duration: 0.28), value: hovering)
        .animation(.smooth(duration: 0.28), value: store.phase)
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.08),
            value: launcherExpanded
        )
        .animation(
            reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.24),
            value: colorTheme
        )
        .onHover { inside in
            hovering = inside
            if store.phase != .idle {
                store.isIslandExpanded = inside
            }
        }
        .contextMenu {
            islandContextMenu
        }
        .popover(isPresented: $store.interruptionNeedsReason) {
            InterruptionReasonPicker()
                .environmentObject(store)
        }
    }

    private var islandTransition: AnyTransition {
        .opacity.combined(
            with: .scale(scale: 0.985, anchor: .top)
        )
    }

    private var idleLauncherSurface: LinearGradient {
        LinearGradient(
            colors: [
                Color.black,
                MossTheme.sageDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var dragHandle: some View {
        ZStack {
            Capsule()
                .fill(.white.opacity(0.36))
                .frame(width: 30, height: 3)
            NativePanelDragHandle(controller: panelController)
        }
        .frame(width: 70, height: 12)
        .help("拖动专注岛")
    }

    private var idleIsland: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(MossTheme.sage.opacity(0.20))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MossTheme.mint)
            }
            .frame(width: 34, height: 34)

            if let task = preferredTask {
                Button {
                    openLauncher(selecting: task)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(MossTypography.font(12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(task.category) · \(task.focusDuration.compactDuration)")
                            .font(MossTypography.font(9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.97))

                IslandQuickActionButton(
                    symbol: "flame.fill",
                    tint: MossTheme.apricot,
                    diameter: 32,
                    emphasis: .quiet,
                    accessibilityLabel: "先做 5 分钟"
                ) {
                    begin(task, mode: .ignition)
                }
                .help("先做 5 分钟")

                IslandQuickActionButton(
                    symbol: "play.fill",
                    tint: MossTheme.mint,
                    diameter: 36,
                    emphasis: .prominent,
                    accessibilityLabel: "开始 \(task.title)"
                ) {
                    begin(task)
                }
                .help("开始 \(task.title)")
            } else {
                Button {
                    store.openMainWindow()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("还没有可开始的任务")
                            .font(MossTypography.font(12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("打开 Moss 添加第一个任务")
                            .font(MossTypography.font(9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.56))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(MossJellyPlainButtonStyle())

                IslandQuickActionButton(
                    symbol: "plus",
                    tint: MossTheme.sage,
                    diameter: 36,
                    emphasis: .prominent,
                    accessibilityLabel: "添加任务"
                ) {
                    store.openMainWindow()
                }
            }

            IslandQuickActionButton(
                symbol: "chevron.down",
                tint: .white,
                diameter: 30,
                emphasis: .quiet,
                accessibilityLabel: "选择任务与计时方式"
            ) {
                openLauncher(selecting: preferredTask)
            }
            .help("选择任务与计时方式")

            IslandQuickActionButton(
                symbol: "xmark",
                tint: .white,
                diameter: 30,
                emphasis: .quiet,
                accessibilityLabel: "隐藏专注岛"
            ) {
                panelController.setVisible(false, store: store)
            }
            .help("隐藏专注岛；可从菜单栏重新显示")
        }
        .padding(.horizontal, 13)
        .frame(width: 510, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(idleLauncherSurface)
                .shadow(color: .black.opacity(0.26), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .help("选择任务、快速开始；拖动可移动专注岛")
        .padding(.top, hasNotch ? 7 : 0)
    }

    private var taskLauncher: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MossTheme.mint)
                    .frame(width: 28, height: 28)
                    .background(MossTheme.sage.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("快速开始")
                        .font(MossTypography.font(13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("今天已完成 \(store.todayCompletedCount) 段")
                        .font(MossTypography.font(9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                Button {
                    store.openMainWindow()
                } label: {
                    Label("打开 Moss", systemImage: "rectangle.on.rectangle")
                        .font(MossTypography.font(9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.94))
                Button {
                    setLauncherExpanded(false)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.70))
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                IslandQuickActionButton(
                    symbol: "xmark",
                    tint: .white,
                    diameter: 28,
                    emphasis: .quiet,
                    accessibilityLabel: "隐藏专注岛"
                ) {
                    panelController.setVisible(false, store: store)
                }
                .help("隐藏专注岛；可从菜单栏重新显示")
            }

            if let task = selectedTask {
                HStack(spacing: 11) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(MossTypography.font(13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(task.category) · 标准 \(task.focusDuration.compactDuration)")
                            .font(MossTypography.font(9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.54))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        begin(task, mode: .ignition)
                    } label: {
                        Label("先做 5 分钟", systemImage: "flame.fill")
                            .font(MossTypography.font(9, weight: .semibold))
                            .foregroundStyle(MossTheme.apricot)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(MossTheme.apricot.opacity(0.13), in: Capsule())
                    }
                    .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.94))

                    Button {
                        begin(task)
                    } label: {
                        Label("开始专注", systemImage: "play.fill")
                            .font(MossTypography.font(10, weight: .bold))
                            .foregroundStyle(.black.opacity(0.78))
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(MossTheme.mint, in: Capsule())
                    }
                    .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.92))
                }
                .padding(.horizontal, 12)
                .frame(height: 50)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MossTheme.sage.opacity(0.20), lineWidth: 1)
                )
            }

            if dataStore.startableTasks.isEmpty {
                VStack(spacing: 8) {
                    Text("还没有可开始的任务")
                        .font(MossTypography.font(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Button("打开 Moss 添加任务") {
                        store.openMainWindow()
                    }
                    .buttonStyle(MossJellyPlainButtonStyle())
                    .foregroundStyle(MossTheme.mint)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("选择任务")
                    .font(MossTypography.font(9, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.42))

                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(dataStore.startableTasks) { task in
                            taskChoice(task)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
                .frame(height: 92)
                .clipped()
            }
        }
        .padding(12)
        .frame(width: 510, height: 232, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(idleLauncherSurface)
                .shadow(color: .black.opacity(0.26), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.top, hasNotch ? 7 : 0)
    }

    private func taskChoice(_ task: FocusTask) -> some View {
        let isSelected = selectedTask?.id == task.id
        return Button {
            selectedTaskID = task.id
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? MossTheme.mint : .white.opacity(0.28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(MossTypography.font(10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)
                    Text("\(task.category) · \(task.focusDuration.compactDuration)")
                        .font(MossTypography.font(8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.44))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.58 : 0.24))
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(
                isSelected ? MossTheme.sage.opacity(0.20) : .white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? MossTheme.mint.opacity(0.38) : .white.opacity(0.055),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.97))
        .mossJellyHover(scale: 1.015, lift: 1, glow: 0.08)
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
                    Color.clear.frame(width: panelController.notchGapWidth, height: 34)
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
        .buttonStyle(MossJellyPlainButtonStyle())
        .accessibilityLabel("打开专注控制")
        .help("打开专注控制；拖动可移动专注岛")
        .padding(.top, hasNotch ? 2 : 0)
    }

    private var expandedIsland: some View {
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                ProgressRing(progress: store.progress, lineWidth: 4, tint: phaseTint)
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(
                            systemName: store.phase == .paused
                                ? "pause.fill"
                                : store.phase == .breakTime
                                    ? "cup.and.saucer.fill"
                                    : "leaf.fill"
                        )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(phaseTint)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseTitle)
                        .font(MossTypography.font(9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(phaseTint)
                    Text(
                        store.transientNotice?.message
                            ?? (store.phase == .breakTime ? BreakPrompt.current : store.currentTaskTitle)
                    )
                        .font(MossTypography.font(12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    if store.phase != .breakTime {
                        Text(store.currentProjectTitle.isEmpty ? store.currentCategory : store.currentProjectTitle)
                            .font(MossTypography.font(8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.displayTime.clockString)
                        .font(MossTypography.font(20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(store.timerDirectionLabel)
                        .font(MossTypography.font(8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.44))
                }
            }

            HStack(spacing: 7) {
                if store.phase == .preparing {
                    islandControlButton("取消开始", symbol: "xmark", tint: MossTheme.brick) {
                        store.cancelStart()
                    }
                } else if store.phase == .focusing {
                    islandControlButton("暂停", symbol: "pause.fill") {
                        store.pause()
                    }
                    islandControlButton("被打断", symbol: "arrow.up.right", tint: MossTheme.apricot) {
                        store.beginOrReturnFromInterruption()
                    }
                    islandControlButton("结束", symbol: "stop.fill", tint: MossTheme.brick) {
                        store.requestEnd()
                    }
                } else if store.phase == .paused {
                    islandControlButton("继续", symbol: "play.fill", tint: MossTheme.mint) {
                        store.resume()
                    }
                    islandControlButton("结束", symbol: "stop.fill", tint: MossTheme.brick) {
                        store.requestEnd()
                    }
                } else if store.phase == .breakTime {
                    islandControlButton("结束休息", symbol: "forward.end.fill", tint: MossTheme.apricot) {
                        store.skipBreak()
                    }
                } else {
                    islandControlButton("完成记录", symbol: "checkmark", tint: MossTheme.mint) {
                        store.presentReview()
                    }
                }

                Spacer(minLength: 5)

                islandControlButton("打开 Moss", symbol: "rectangle.on.rectangle", tint: .white.opacity(0.22)) {
                    store.openMainWindow()
                }
                islandIconButton("chevron.up", accessibilityLabel: "收起专注控制") {
                    store.isIslandExpanded = false
                }
                islandIconButton("xmark", accessibilityLabel: "隐藏专注岛") {
                    panelController.setVisible(false, store: store)
                }
                .help("隐藏专注岛；计时会继续")
            }
        }
        .padding(.horizontal, 15)
        .frame(width: 530, height: 98)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(Color.black.opacity(0.95))
                .shadow(color: .black.opacity(0.26), radius: 15, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.top, hasNotch ? 7 : 2)
    }

    private func islandControlButton(
        _ title: String,
        symbol: String,
        tint: Color = MossTheme.sage,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(MossTypography.font(9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(tint.opacity(0.58), in: Capsule())
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.92))
    }

    private func islandIconButton(
        _ symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var islandContextMenu: some View {
        if store.phase == .idle {
            if let task = preferredTask {
                Button {
                    begin(task)
                } label: {
                    Label("开始 \(task.title)", systemImage: "play.fill")
                }
                Button {
                    begin(task, mode: .ignition)
                } label: {
                    Label("先做 5 分钟", systemImage: "flame.fill")
                }
                Divider()
            }
            Button {
                openLauncher(selecting: preferredTask)
            } label: {
                Label("选择任务与计时方式", systemImage: "list.bullet.rectangle")
            }
        } else if store.phase == .preparing {
            Button {
                store.cancelStart()
            } label: {
                Label("取消开始", systemImage: "xmark")
            }
        } else if store.phase == .focusing {
            Button {
                store.pause()
            } label: {
                Label("暂停专注", systemImage: "pause.fill")
            }
            Button {
                store.beginOrReturnFromInterruption()
            } label: {
                Label("记录打断", systemImage: "arrow.up.right")
            }
            Button {
                store.requestEnd()
            } label: {
                Label("结束并记录", systemImage: "stop.fill")
            }
        } else if store.phase == .paused {
            Button {
                store.resume()
            } label: {
                Label("继续专注", systemImage: "play.fill")
            }
            Button {
                store.requestEnd()
            } label: {
                Label("结束并记录", systemImage: "stop.fill")
            }
        } else if store.phase == .breakTime {
            Button {
                store.skipBreak()
            } label: {
                Label("结束休息", systemImage: "forward.end.fill")
            }
        } else {
            Button {
                store.presentReview()
            } label: {
                Label("完成记录", systemImage: "checkmark")
            }
        }

        Divider()

        Button {
            store.openMainWindow()
        } label: {
            Label("打开 Moss", systemImage: "rectangle.on.rectangle")
        }
        Button {
            panelController.resetPosition()
        } label: {
            Label("重置专注岛位置", systemImage: "scope")
        }
        Button {
            panelController.setVisible(false, store: store)
        } label: {
            Label("隐藏专注岛", systemImage: "eye.slash")
        }
    }

    private func openLauncher(selecting task: FocusTask?) {
        selectedTaskID = task?.id ?? selectedTaskID
        setLauncherExpanded(true)
    }

    private func begin(_ task: FocusTask, mode: FocusMode = .standard) {
        selectedTaskID = task.id
        setLauncherExpanded(false)
        store.start(task: task, mode: mode)
    }

    private func setLauncherExpanded(_ expanded: Bool) {
        guard launcherExpanded != expanded else { return }
        if reduceMotion {
            launcherExpanded = expanded
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.08)) {
                launcherExpanded = expanded
            }
        }
    }

    private func islandLobe<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(Color.black.opacity(0.94), in: Capsule())
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

private enum IslandQuickActionEmphasis {
    case quiet
    case prominent
}

private struct IslandQuickActionButton: View {
    let symbol: String
    let tint: Color
    let diameter: CGFloat
    let emphasis: IslandQuickActionEmphasis
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(foregroundColor)
                .frame(width: diameter, height: diameter)
                .background(backgroundColor, in: Circle())
                .overlay {
                    Circle()
                        .stroke(tint.opacity(borderOpacity), lineWidth: 1)
                }
                .shadow(
                    color: tint.opacity(isHovered ? 0.20 : 0),
                    radius: isHovered ? 8 : 0,
                    y: isHovered ? 3 : 0
                )
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.88))
        .scaleEffect(isHovered && !reduceMotion ? 1.055 : 1)
        .onHover { hovering in
            withAnimation(
                reduceMotion
                    ? .linear(duration: 0.01)
                    : .easeInOut(duration: 0.18)
            ) {
                isHovered = hovering
            }
        }
        .animation(
            reduceMotion
                ? .linear(duration: 0.01)
                : .spring(response: 0.28, dampingFraction: 0.76, blendDuration: 0.05),
            value: isHovered
        )
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        switch emphasis {
        case .quiet:
            tint.opacity(isHovered ? 0.18 : 0.09)
        case .prominent:
            tint.opacity(isHovered ? 0.90 : 0.72)
        }
    }

    private var foregroundColor: Color {
        switch emphasis {
        case .quiet:
            tint.opacity(isHovered ? 0.98 : 0.78)
        case .prominent:
            Color.black.opacity(isHovered ? 0.86 : 0.74)
        }
    }

    private var borderOpacity: Double {
        switch emphasis {
        case .quiet:
            isHovered ? 0.24 : 0.10
        case .prominent:
            isHovered ? 0.44 : 0.24
        }
    }
}

@MainActor
private struct NativePanelDragHandle: NSViewRepresentable {
    let controller: NotchPanelController

    func makeNSView(context: Context) -> NativePanelDragView {
        let view = NativePanelDragView()
        view.controller = controller
        return view
    }

    func updateNSView(_ nsView: NativePanelDragView, context: Context) {
        nsView.controller = controller
    }
}

@MainActor
private final class NativePanelDragView: NSView {
    weak var controller: NotchPanelController?

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        controller?.performNativeDrag(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
