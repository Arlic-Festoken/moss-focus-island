import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class DesktopWidgetPanelController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = DesktopWidgetPanelController()

    @Published private(set) var isVisible = false

    private let size = CGSize(width: 352, height: 218)
    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?

    private override init() {
        super.init()
    }

    func show(store: AppStore, dataStore: DataStore) {
        guard UserDefaults.standard.object(forKey: "showDesktopWidget") as? Bool ?? false else {
            isVisible = false
            return
        }

        if panel == nil {
            let panel = DesktopWidgetPanel(
                contentRect: CGRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.identifier = NSUserInterfaceItemIdentifier("moss.desktop.widget")
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = NSWindow.Level(
                rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
            )
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.isMovable = true
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            panel.contentViewController = NSHostingController(
                rootView: DesktopFocusWidgetView(dataStore: dataStore)
                    .environmentObject(store)
            )
            self.panel = panel
        }

        reposition()
        panel?.orderFrontRegardless()
        isVisible = true

        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reposition()
                }
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func setVisible(_ visible: Bool, store: AppStore, dataStore: DataStore) {
        UserDefaults.standard.set(visible, forKey: "showDesktopWidget")
        visible ? show(store: store, dataStore: dataStore) : hide()
    }

    func resetPosition() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "desktopWidgetX")
        defaults.removeObject(forKey: "desktopWidgetY")
        reposition()
    }

    func performNativeDrag(with event: NSEvent) {
        guard let panel else { return }
        panel.performDrag(with: event)
        savePosition(panel.frame.origin)
    }

    func windowDidMove(_ notification: Notification) {
        guard let movedPanel = notification.object as? NSPanel,
              movedPanel === panel else { return }
        savePosition(movedPanel.frame.origin)
    }

    private func reposition() {
        guard let panel, let screen = preferredScreen(for: panel.frame) else { return }
        let visibleFrame = screen.visibleFrame
        let defaults = UserDefaults.standard
        let hasSavedPosition = defaults.object(forKey: "desktopWidgetX") != nil
            && defaults.object(forKey: "desktopWidgetY") != nil
        let origin: CGPoint
        if hasSavedPosition {
            origin = CGPoint(
                x: defaults.double(forKey: "desktopWidgetX"),
                y: defaults.double(forKey: "desktopWidgetY")
            )
        } else {
            origin = CGPoint(
                x: visibleFrame.maxX - size.width - 28,
                y: visibleFrame.minY + 38
            )
        }
        let frame = clamped(
            CGRect(origin: origin, size: size),
            to: visibleFrame.insetBy(dx: 10, dy: 10)
        )
        panel.setFrame(frame, display: true, animate: false)
        savePosition(frame.origin)
    }

    private func preferredScreen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func clamped(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        let maxX = max(bounds.minX, bounds.maxX - frame.width)
        let maxY = max(bounds.minY, bounds.maxY - frame.height)
        return CGRect(
            x: min(max(frame.minX, bounds.minX), maxX),
            y: min(max(frame.minY, bounds.minY), maxY),
            width: frame.width,
            height: frame.height
        )
    }

    private func savePosition(_ origin: CGPoint) {
        let defaults = UserDefaults.standard
        defaults.set(origin.x, forKey: "desktopWidgetX")
        defaults.set(origin.y, forKey: "desktopWidgetY")
    }
}

private final class DesktopWidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct DesktopFocusWidgetView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var dataStore: DataStore
    @ObservedObject private var panelController = DesktopWidgetPanelController.shared
    @AppStorage("colorTheme") private var colorTheme = MossColorTheme.sage.rawValue
    @State private var selectedTaskID: FocusTask.ID?

    init(dataStore: DataStore) {
        _dataStore = ObservedObject(wrappedValue: dataStore)
    }

    private var selectedTask: FocusTask? {
        if let selectedTaskID,
           let task = dataStore.startableTasks.first(where: { $0.id == selectedTaskID }) {
            return task
        }
        return dataStore.preferredStartTask
    }

    private var todayFocus: TimeInterval {
        dataStore.sessions
            .filter { $0.startedAt >= Date.now.dayStart && $0.status == .completed }
            .reduce(0) { $0 + $1.actualFocusDuration }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(.white.opacity(0.06))
                .padding(.horizontal, 16)
            Group {
                if store.phase == .idle {
                    idleContent
                } else {
                    activeContent
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 340, height: 206)
        .background(widgetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 24, y: 12)
        .frame(width: 352, height: 218)
        .mossTypography()
        .tint(MossColorTheme(rawValue: colorTheme)?.accent ?? MossTheme.sage)
        .contextMenu {
            Button {
                store.openMainWindow()
            } label: {
                Label("打开 Moss", systemImage: "rectangle.on.rectangle")
            }
            Button {
                panelController.resetPosition()
            } label: {
                Label("重置小组件位置", systemImage: "scope")
            }
            Divider()
            Button {
                panelController.setVisible(false, store: store, dataStore: dataStore)
            } label: {
                Label("隐藏桌面小组件", systemImage: "eye.slash")
            }
        }
    }

    private var widgetSurface: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.black.opacity(0.94),
                MossTheme.sageDeep.opacity(0.97),
                Color.black.opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(spacing: 0) {
            ZStack {
                DesktopWidgetDragHandle(controller: panelController)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(MossTheme.sage.opacity(0.20))
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MossTheme.mint)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Moss 桌面伴侣")
                            .font(MossTypography.font(11, weight: .bold))
                            .foregroundStyle(.white)
                        Text(store.phase == .idle ? "准备好时，从这里开始" : phaseTitle)
                            .font(MossTypography.font(8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer()

                    Capsule()
                        .fill(.white.opacity(0.24))
                        .frame(width: 34, height: 3)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .help("拖动桌面小组件")

            Button {
                panelController.setVisible(false, store: store, dataStore: dataStore)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
            .help("隐藏桌面小组件")
            .accessibilityLabel("隐藏桌面小组件")
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .frame(height: 52)
    }

    private var idleContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("下一段专注")
                        .font(MossTypography.font(8, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(MossTheme.mint.opacity(0.78))

                    if dataStore.startableTasks.isEmpty {
                        Text("还没有可开始的任务")
                            .font(MossTypography.font(14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    } else {
                        Menu {
                            ForEach(dataStore.startableTasks) { task in
                                Button {
                                    selectedTaskID = task.id
                                } label: {
                                    Label(task.title, systemImage: task.timerActivity.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedTask?.title ?? "选择任务")
                                    .font(MossTypography.font(14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(
                        selectedTask.map {
                            "\($0.category) · \($0.focusDuration.compactDuration)"
                        } ?? "打开 Moss 添加第一个任务"
                    )
                    .font(MossTypography.font(9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(todayFocus.compactDuration)
                        .font(MossTypography.font(17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("今日专注")
                        .font(MossTypography.font(8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            HStack(spacing: 9) {
                if let task = selectedTask {
                    widgetActionButton("先做 5 分钟", symbol: "flame.fill", tint: MossTheme.apricot) {
                        store.start(task: task, mode: .ignition)
                    }
                    widgetActionButton("开始专注", symbol: "play.fill", tint: MossTheme.mint, prominent: true) {
                        store.start(task: task)
                    }
                } else {
                    widgetActionButton("打开 Moss 添加任务", symbol: "plus", tint: MossTheme.mint, prominent: true) {
                        store.openMainWindow()
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var activeContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 13) {
                ProgressRing(progress: store.progress, lineWidth: 4, tint: phaseTint)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: phaseSymbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(phaseTint)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.currentTaskTitle.isEmpty ? phaseTitle : store.currentTaskTitle)
                        .font(MossTypography.font(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(store.currentProjectTitle.isEmpty ? store.timerDirectionLabel : store.currentProjectTitle)
                        .font(MossTypography.font(9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(store.displayTime.clockString)
                        .font(MossTypography.font(22, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(store.timerDirectionLabel)
                        .font(MossTypography.font(8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            HStack(spacing: 9) {
                if store.phase == .preparing {
                    widgetActionButton("取消", symbol: "xmark", tint: MossTheme.brick) {
                        store.cancelStart()
                    }
                } else if store.phase == .focusing {
                    widgetActionButton("暂停", symbol: "pause.fill", tint: MossTheme.sage) {
                        store.pause()
                    }
                    widgetActionButton("结束", symbol: "stop.fill", tint: MossTheme.brick) {
                        store.requestEnd()
                    }
                } else if store.phase == .paused {
                    widgetActionButton("继续", symbol: "play.fill", tint: MossTheme.mint, prominent: true) {
                        store.resume()
                    }
                    widgetActionButton("结束", symbol: "stop.fill", tint: MossTheme.brick) {
                        store.requestEnd()
                    }
                } else if store.phase == .breakTime {
                    widgetActionButton("结束休息", symbol: "forward.end.fill", tint: MossTheme.apricot, prominent: true) {
                        store.skipBreak()
                    }
                } else {
                    widgetActionButton("完成记录", symbol: "checkmark", tint: MossTheme.mint, prominent: true) {
                        store.presentReview()
                    }
                }

                Spacer(minLength: 4)

                Button {
                    store.openMainWindow()
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                .help("打开 Moss")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private func widgetActionButton(
        _ title: String,
        symbol: String,
        tint: Color,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(MossTypography.font(9, weight: .semibold))
                .foregroundStyle(prominent ? MossTheme.current.accentForeground : .white.opacity(0.88))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    prominent ? tint : tint.opacity(0.38),
                    in: Capsule()
                )
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.92))
    }

    private var phaseTint: Color {
        switch store.phase {
        case .breakTime, .preparing: MossTheme.apricot
        case .paused: .white.opacity(0.72)
        case .awaitingReview: MossTheme.mint
        case .idle, .focusing: MossTheme.mint
        }
    }

    private var phaseTitle: String {
        switch store.phase {
        case .idle: "等待下一段专注"
        case .preparing: "正在进入状态"
        case .focusing: "专注进行中"
        case .paused: "专注已暂停"
        case .breakTime: "休息一下"
        case .awaitingReview: "等待完成记录"
        }
    }

    private var phaseSymbol: String {
        switch store.phase {
        case .idle, .focusing: "leaf.fill"
        case .preparing: "sparkles"
        case .paused: "pause.fill"
        case .breakTime: "cup.and.saucer.fill"
        case .awaitingReview: "checkmark"
        }
    }
}

private struct DesktopWidgetDragHandle: NSViewRepresentable {
    let controller: DesktopWidgetPanelController

    func makeNSView(context: Context) -> DesktopWidgetDragView {
        DesktopWidgetDragView(controller: controller)
    }

    func updateNSView(_ nsView: DesktopWidgetDragView, context: Context) {
        nsView.controller = controller
    }
}

private final class DesktopWidgetDragView: NSView {
    weak var controller: DesktopWidgetPanelController?

    init(controller: DesktopWidgetPanelController) {
        self.controller = controller
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        controller?.performNativeDrag(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
