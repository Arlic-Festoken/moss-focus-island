import AppKit
import CoreGraphics
import SwiftUI

enum CompanionMotionMode: String, CaseIterable, Identifiable {
    case quiet
    case lively

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: "安静"
        case .lively: "活泼"
        }
    }

    var subtitle: String {
        switch self {
        case .quiet: "只保留呼吸与状态反馈"
        case .lively: "增加漂浮、眨眼与互动回应"
        }
    }
}

enum CompanionWindowLayer: String, CaseIterable, Identifiable {
    case desktop
    case floating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktop: "停在桌面"
        case .floating: "浮在窗口上方"
        }
    }

    var symbol: String {
        switch self {
        case .desktop: "macwindow.on.rectangle"
        case .floating: "square.on.square"
        }
    }
}

enum CompanionSize: String, CaseIterable, Identifiable {
    case compact
    case regular
    case generous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "小"
        case .regular: "中"
        case .generous: "大"
        }
    }

    var panelSize: CGSize {
        switch self {
        case .compact: CGSize(width: 176, height: 190)
        case .regular: CGSize(width: 216, height: 226)
        case .generous: CGSize(width: 256, height: 268)
        }
    }

    var characterSize: CGFloat {
        switch self {
        case .compact: 92
        case .regular: 118
        case .generous: 146
        }
    }
}

enum CompanionPose: String, Equatable {
    case waiting
    case waking
    case focusing
    case concerned
    case resting
    case celebrating
    case reflecting
}

struct CompanionPresentation: Equatable {
    let pose: CompanionPose
    let status: String
    let symbol: String
    let dialogue: String

    static func make(
        phase: FocusPhase,
        theme: GrowthTheme,
        interactionIndex: Int,
        taskTitle: String,
        todayCompletedCount: Int
    ) -> CompanionPresentation {
        let themeLines: [String]
        switch theme {
        case .moss:
            themeLines = [
                "不用一下完成整座岛，先种下这一小段。",
                "我会替你守着节奏，你只管把注意力放回来。",
                "真实投入都会留下痕迹，慢一点也没有关系。",
                "准备好时，我们就从五分钟开始。"
            ]
        case .douluo:
            themeLines = [
                "真正的成长来自完成过的每一段修炼。",
                "先稳住呼吸，再把注意力放回眼前。",
                "今天积累的时间，会变成下一次出发的底气。",
                "不用追赶谁，只需要完成自己的这一段。"
            ]
        }

        switch phase {
        case .idle:
            let index = abs(interactionIndex) % themeLines.count
            return CompanionPresentation(
                pose: todayCompletedCount > 0 ? .celebrating : .waiting,
                status: todayCompletedCount > 0 ? "今天已并肩 \(todayCompletedCount) 段" : "等你一起出发",
                symbol: todayCompletedCount > 0 ? "checkmark.seal.fill" : "leaf.fill",
                dialogue: themeLines[index]
            )
        case .preparing:
            return CompanionPresentation(
                pose: .waking,
                status: "正在进入状态",
                symbol: "sparkles",
                dialogue: "先放松肩膀。等呼吸稳下来，我们再开始计时。"
            )
        case .focusing:
            return CompanionPresentation(
                pose: .focusing,
                status: taskTitle.isEmpty ? "安静陪你专注" : "陪你做「\(taskTitle)」",
                symbol: "circle.dotted.circle.fill",
                dialogue: "我在这里守着，不打扰你。"
            )
        case .paused:
            return CompanionPresentation(
                pose: .concerned,
                status: "这一段暂时停住",
                symbol: "pause.fill",
                dialogue: "离开一下没关系，回来时从最小的一步接上。"
            )
        case .breakTime:
            return CompanionPresentation(
                pose: .resting,
                status: "一起休息",
                symbol: "cup.and.saucer.fill",
                dialogue: "看看远处，喝口水。休息也属于这段专注。"
            )
        case .awaitingReview:
            return CompanionPresentation(
                pose: .reflecting,
                status: "等待收下这段记录",
                symbol: "text.book.closed.fill",
                dialogue: "把完成情况和感受记下来，这段时间才真正落地。"
            )
        }
    }
}

enum CompanionPanelGeometry {
    static func defaultFrame(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.maxX - size.width - 26,
            y: visibleFrame.minY + 34,
            width: size.width,
            height: size.height
        )
    }

    static func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: 8, dy: 8)
        let maxX = max(bounds.minX, bounds.maxX - frame.width)
        let maxY = max(bounds.minY, bounds.maxY - frame.height)
        return CGRect(
            x: min(max(frame.minX, bounds.minX), maxX),
            y: min(max(frame.minY, bounds.minY), maxY),
            width: frame.width,
            height: frame.height
        )
    }
}

@MainActor
final class DesktopCompanionPanelController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = DesktopCompanionPanelController()

    @Published private(set) var isVisible = false
    @Published private(set) var isLocked: Bool

    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []

    private override init() {
        isLocked = UserDefaults.standard.bool(forKey: "companionPositionLocked")
        super.init()
    }

    func show(store: AppStore, dataStore: DataStore) {
        guard UserDefaults.standard.object(forKey: "showDesktopCompanion") as? Bool ?? false else {
            isVisible = false
            return
        }

        if panel == nil {
            createPanel(store: store, dataStore: dataStore)
        }

        refreshPreferences()
        reposition()
        isVisible = true
        refreshVisibilityForCurrentSpace()
        installObserversIfNeeded()
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func setVisible(_ visible: Bool, store: AppStore, dataStore: DataStore) {
        UserDefaults.standard.set(visible, forKey: "showDesktopCompanion")
        visible ? show(store: store, dataStore: dataStore) : hide()
    }

    func setLocked(_ locked: Bool) {
        UserDefaults.standard.set(locked, forKey: "companionPositionLocked")
        isLocked = locked
    }

    func refreshPreferences() {
        guard let panel else { return }
        isLocked = UserDefaults.standard.bool(forKey: "companionPositionLocked")

        let layer = CompanionWindowLayer(
            rawValue: UserDefaults.standard.string(forKey: "companionWindowLayer") ?? ""
        ) ?? .desktop
        panel.level = layer == .floating
            ? .floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        panel.collectionBehavior = layer == .floating
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            : [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let targetSize = currentSize.panelSize
        if panel.frame.size != targetSize {
            let bottomCenter = CGPoint(x: panel.frame.midX, y: panel.frame.minY)
            let resizedFrame = CGRect(
                x: bottomCenter.x - targetSize.width / 2,
                y: bottomCenter.y,
                width: targetSize.width,
                height: targetSize.height
            )
            panel.setFrame(resizedFrame, display: true, animate: false)
            reposition()
        }
        refreshVisibilityForCurrentSpace()
    }

    func resetPosition() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "companionPanelX")
        defaults.removeObject(forKey: "companionPanelY")
        reposition()
    }

    func performNativeDrag(with event: NSEvent) {
        guard let panel, !isLocked else { return }
        panel.performDrag(with: event)
        savePosition(panel.frame.origin)
    }

    func windowDidMove(_ notification: Notification) {
        guard let movedPanel = notification.object as? NSPanel,
              movedPanel === panel else { return }
        savePosition(movedPanel.frame.origin)
    }

    private var currentSize: CompanionSize {
        CompanionSize(
            rawValue: UserDefaults.standard.string(forKey: "companionSize") ?? ""
        ) ?? .regular
    }

    private func createPanel(store: AppStore, dataStore: DataStore) {
        let size = currentSize.panelSize
        let panel = DesktopCompanionPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier("moss.desktop.companion")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentViewController = NSHostingController(
            rootView: DesktopCompanionView(dataStore: dataStore)
                .environmentObject(store)
                .mossTypography()
        )
        self.panel = panel
    }

    private func installObserversIfNeeded() {
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.reposition()
                    self?.refreshVisibilityForCurrentSpace()
                }
            }
        }

        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]
        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshVisibilityForCurrentSpace()
                }
            }
        }
    }

    private func reposition() {
        guard let panel, let screen = preferredScreen(for: panel.frame) else { return }
        let defaults = UserDefaults.standard
        let size = currentSize.panelSize
        let hasSavedPosition = defaults.object(forKey: "companionPanelX") != nil
            && defaults.object(forKey: "companionPanelY") != nil
        let candidate: CGRect
        if hasSavedPosition {
            candidate = CGRect(
                x: defaults.double(forKey: "companionPanelX"),
                y: defaults.double(forKey: "companionPanelY"),
                width: size.width,
                height: size.height
            )
        } else {
            candidate = CompanionPanelGeometry.defaultFrame(
                size: size,
                in: screen.visibleFrame
            )
        }
        let frame = CompanionPanelGeometry.clamped(candidate, to: screen.visibleFrame)
        panel.setFrame(frame, display: true, animate: false)
        savePosition(frame.origin)
    }

    private func preferredScreen(for frame: CGRect) -> NSScreen? {
        NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func savePosition(_ origin: CGPoint) {
        let defaults = UserDefaults.standard
        defaults.set(origin.x, forKey: "companionPanelX")
        defaults.set(origin.y, forKey: "companionPanelY")
    }

    private func refreshVisibilityForCurrentSpace() {
        guard let panel, isVisible else { return }
        let hidesInFullScreen = UserDefaults.standard.object(
            forKey: "companionHideInFullScreen"
        ) as? Bool ?? true
        let layer = CompanionWindowLayer(
            rawValue: UserDefaults.standard.string(forKey: "companionWindowLayer") ?? ""
        ) ?? .desktop
        if hidesInFullScreen, layer == .floating, frontmostApplicationIsFullScreen {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private var frontmostApplicationIsFullScreen: Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
              ) as? [[String: Any]] else {
            return false
        }

        return windowInfo.contains { entry in
            guard entry[kCGWindowOwnerPID as String] as? pid_t == pid,
                  entry[kCGWindowLayer as String] as? Int == 0,
                  let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  let x = (bounds["X"] as? NSNumber)?.doubleValue,
                  let y = (bounds["Y"] as? NSNumber)?.doubleValue,
                  let width = (bounds["Width"] as? NSNumber)?.doubleValue,
                  let height = (bounds["Height"] as? NSNumber)?.doubleValue else {
                return false
            }
            let frame = CGRect(x: x, y: y, width: width, height: height)
            return NSScreen.screens.contains { screen in
                abs(frame.minX - screen.frame.minX) < 2
                    && abs(frame.minY - screen.frame.minY) < 2
                    && abs(frame.width - screen.frame.width) < 2
                    && abs(frame.height - screen.frame.height) < 2
            }
        }
    }
}

private final class DesktopCompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum CompanionCharacterStyle {
    case moss
    case soulMaster
    case soulBeast
}

struct MossCompanionCharacter: View {
    let pose: CompanionPose
    let style: CompanionCharacterStyle
    let progress: Double
    let motionMode: CompanionMotionMode
    var dimension: CGFloat = 118
    var isInteracting = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: motionMode == .lively ? 1.0 / 24.0 : 1.0 / 12.0,
                paused: reduceMotion
            )
        ) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let wave = reduceMotion ? 0 : sin(time * motionSpeed)
            character(wave: wave)
        }
        .frame(width: dimension, height: dimension)
        .accessibilityHidden(true)
    }

    private func character(wave: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0.03), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: dimension * 0.5
                    )
                )

            if pose == .focusing {
                Circle()
                    .trim(from: 0, to: max(0.035, min(1, progress)))
                    .stroke(
                        tint.opacity(0.72),
                        style: StrokeStyle(
                            lineWidth: max(2, dimension * 0.025),
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(dimension * 0.055)
            }

            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: dimension * 0.55, height: dimension * 0.11)
                .blur(radius: dimension * 0.025)
                .offset(y: dimension * 0.34)
                .scaleEffect(x: 1 - abs(wave) * 0.04)

            decoration
                .offset(y: -dimension * 0.30 + CGFloat(wave) * floatAmount)

            ZStack {
                RoundedRectangle(
                    cornerRadius: dimension * 0.28,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.96), deepTint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: dimension * 0.59, height: dimension * 0.55)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: dimension * 0.28,
                        style: .continuous
                    )
                    .stroke(.white.opacity(0.23), lineWidth: 1)
                }
                .shadow(
                    color: tint.opacity(0.25),
                    radius: dimension * 0.08,
                    y: dimension * 0.045
                )

                face
            }
            .rotationEffect(.degrees(characterRotation(wave)))
            .scaleEffect(characterScale(wave))
            .offset(y: CGFloat(wave) * floatAmount)

            if pose == .celebrating || isInteracting {
                Image(systemName: pose == .celebrating ? "sparkles" : "heart.fill")
                    .font(.system(size: dimension * 0.13, weight: .bold))
                    .foregroundStyle(pose == .celebrating ? MossTheme.apricot : MossTheme.brick)
                    .offset(x: dimension * 0.31, y: -dimension * 0.25)
                    .scaleEffect(1 + abs(wave) * 0.12)
            }
        }
    }

    @ViewBuilder
    private var decoration: some View {
        switch style {
        case .moss:
            HStack(spacing: -3) {
                MossLeafShape()
                    .fill(MossTheme.mint)
                    .frame(width: dimension * 0.24, height: dimension * 0.31)
                    .rotationEffect(.degrees(-28))
                MossLeafShape()
                    .fill(MossTheme.sage)
                    .frame(width: dimension * 0.22, height: dimension * 0.28)
                    .rotationEffect(.degrees(28))
            }
        case .soulMaster:
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.48), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: dimension * 0.47, height: dimension * 0.18)
                    .rotationEffect(.degrees(8))
                MossLeafShape()
                    .fill(MossTheme.mint)
                    .frame(width: dimension * 0.20, height: dimension * 0.27)
            }
        case .soulBeast:
            HStack(spacing: dimension * 0.24) {
                Capsule()
                    .fill(tint)
                    .frame(width: dimension * 0.10, height: dimension * 0.25)
                    .rotationEffect(.degrees(-24))
                Capsule()
                    .fill(tint)
                    .frame(width: dimension * 0.10, height: dimension * 0.25)
                    .rotationEffect(.degrees(24))
            }
        }
    }

    private var face: some View {
        VStack(spacing: dimension * 0.075) {
            HStack(spacing: dimension * 0.16) {
                eye
                eye
            }
            Capsule()
                .fill(faceColor.opacity(0.72))
                .frame(
                    width: pose == .concerned ? dimension * 0.10 : dimension * 0.15,
                    height: max(2, dimension * 0.026)
                )
                .rotationEffect(.degrees(pose == .concerned ? -8 : 0))
        }
        .offset(y: dimension * 0.035)
    }

    private var eye: some View {
        Capsule()
            .fill(faceColor)
            .frame(
                width: max(3, dimension * 0.045),
                height: eyeHeight
            )
    }

    private var eyeHeight: CGFloat {
        switch pose {
        case .resting: max(2, dimension * 0.025)
        case .focusing: dimension * 0.075
        case .celebrating: max(3, dimension * 0.038)
        default: dimension * 0.095
        }
    }

    private var tint: Color {
        switch style {
        case .moss: MossTheme.sage
        case .soulMaster: MossTheme.sageDeep
        case .soulBeast: TitleGroup.exploration.color
        }
    }

    private var deepTint: Color {
        switch style {
        case .moss: MossTheme.sageDeep
        case .soulMaster: Color(red: 0.16, green: 0.27, blue: 0.25)
        case .soulBeast: Color(red: 0.24, green: 0.18, blue: 0.34)
        }
    }

    private var faceColor: Color {
        style == .soulBeast ? .white.opacity(0.82) : MossTheme.current.accentForeground
    }

    private var motionSpeed: Double {
        switch pose {
        case .focusing: 0.8
        case .resting: 0.55
        default: motionMode == .lively ? 1.9 : 0.9
        }
    }

    private var floatAmount: CGFloat {
        if pose == .focusing { return dimension * 0.006 }
        return dimension * (motionMode == .lively ? 0.028 : 0.012)
    }

    private func characterRotation(_ wave: Double) -> Double {
        guard pose != .focusing else { return 0 }
        let amount = motionMode == .lively ? 2.2 : 0.7
        return wave * amount
    }

    private func characterScale(_ wave: Double) -> CGFloat {
        let breathing = CGFloat((wave + 1) / 2)
        let amount: CGFloat = pose == .focusing ? 0.008 : motionMode == .lively ? 0.025 : 0.012
        return 1 + breathing * amount + (isInteracting ? 0.035 : 0)
    }
}

private struct MossLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY * 0.70),
            control2: CGPoint(x: rect.minX, y: rect.minY * 1.2)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.minY * 1.2),
            control2: CGPoint(x: rect.maxX, y: rect.maxY * 0.70)
        )
        return path
    }
}

private struct DesktopCompanionView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var dataStore: DataStore
    @ObservedObject private var panelController = DesktopCompanionPanelController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("growthTheme") private var growthThemeRaw = GrowthTheme.douluo.rawValue
    @AppStorage("douluoAvatarForm") private var avatarFormRaw = DouluoAvatarForm.soulMaster.rawValue
    @AppStorage("companionMotionMode") private var motionModeRaw = CompanionMotionMode.quiet.rawValue
    @AppStorage("companionWindowLayer") private var windowLayerRaw = CompanionWindowLayer.desktop.rawValue
    @AppStorage("companionSize") private var companionSizeRaw = CompanionSize.regular.rawValue
    @AppStorage("companionHideInFullScreen") private var hideInFullScreen = true
    @State private var interactionIndex = 0
    @State private var speechRevision = 0
    @State private var showsSpeech = false
    @State private var isHovered = false
    @State private var isInteracting = false

    init(dataStore: DataStore) {
        _dataStore = ObservedObject(wrappedValue: dataStore)
    }

    private var theme: GrowthTheme {
        GrowthTheme(rawValue: growthThemeRaw) ?? .moss
    }

    private var avatarForm: DouluoAvatarForm {
        DouluoAvatarForm(rawValue: avatarFormRaw) ?? .soulMaster
    }

    private var motionMode: CompanionMotionMode {
        CompanionMotionMode(rawValue: motionModeRaw) ?? .quiet
    }

    private var companionSize: CompanionSize {
        CompanionSize(rawValue: companionSizeRaw) ?? .regular
    }

    private var characterStyle: CompanionCharacterStyle {
        if theme == .moss { return .moss }
        return avatarForm == .soulMaster ? .soulMaster : .soulBeast
    }

    private var presentation: CompanionPresentation {
        CompanionPresentation.make(
            phase: store.phase,
            theme: theme,
            interactionIndex: interactionIndex,
            taskTitle: store.currentTaskTitle,
            todayCompletedCount: store.todayCompletedCount
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            speechBubble
                .opacity(showsSpeech || isHovered ? 1 : 0)
                .offset(y: showsSpeech || isHovered ? 0 : 4)

            Button(action: interact) {
                MossCompanionCharacter(
                    pose: presentation.pose,
                    style: characterStyle,
                    progress: store.progress,
                    motionMode: motionMode,
                    dimension: companionSize.characterSize,
                    isInteracting: isInteracting
                )
            }
            .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.96))
            .help("轻点伙伴")
            .accessibilityLabel("Moss 桌面伙伴，\(presentation.status)")

            statusCapsule

            ZStack {
                CompanionDragHandle(controller: panelController)
                Capsule()
                    .fill(MossTheme.sage.opacity(panelController.isLocked ? 0.08 : 0.22))
                    .frame(width: 34, height: 4)
                    .allowsHitTesting(false)
            }
            .frame(width: 70, height: 14)
            .help(panelController.isLocked ? "位置已锁定" : "拖动伙伴")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(
            width: companionSize.panelSize.width,
            height: companionSize.panelSize.height,
            alignment: .bottom
        )
        .onHover { isHovered = $0 }
        .contextMenu { companionMenu }
        .task(id: speechRevision) {
            guard speechRevision > 0 else { return }
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeOut(duration: 0.18)) {
                showsSpeech = true
            }
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled, !isHovered else { return }
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .easeIn(duration: 0.22)) {
                showsSpeech = false
                isInteracting = false
            }
        }
        .onAppear {
            speechRevision += 1
        }
        .onChange(of: store.phase) { _, _ in
            speechRevision += 1
        }
    }

    private var speechBubble: some View {
        Text(presentation.dialogue)
            .font(MossTypography.font(companionSize == .compact ? 9 : 10, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.82))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(maxWidth: companionSize.panelSize.width - 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(MossTheme.sage.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
    }

    private var statusCapsule: some View {
        Label(presentation.status, systemImage: presentation.symbol)
            .font(MossTypography.font(companionSize == .compact ? 8 : 9, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(colorScheme == .dark ? MossTheme.mint : MossTheme.sageDeep)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                colorScheme == .dark
                    ? Color.black.opacity(0.74)
                    : MossTheme.paper.opacity(0.92),
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(MossTheme.sage.opacity(0.16), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var companionMenu: some View {
        Button {
            store.openMainWindow()
        } label: {
            Label("打开 Moss", systemImage: "rectangle.on.rectangle")
        }

        Divider()

        Picker("陪伴节奏", selection: $motionModeRaw) {
            ForEach(CompanionMotionMode.allCases) { mode in
                Text(mode.title).tag(mode.rawValue)
            }
        }

        Picker("伙伴尺寸", selection: $companionSizeRaw) {
            ForEach(CompanionSize.allCases) { size in
                Text(size.title).tag(size.rawValue)
            }
        }
        .onChange(of: companionSizeRaw) { _, _ in
            panelController.refreshPreferences()
        }

        Picker("显示层级", selection: $windowLayerRaw) {
            ForEach(CompanionWindowLayer.allCases) { layer in
                Label(layer.title, systemImage: layer.symbol)
                    .tag(layer.rawValue)
            }
        }
        .onChange(of: windowLayerRaw) { _, _ in
            panelController.refreshPreferences()
        }

        Toggle("全屏时自动收起", isOn: $hideInFullScreen)
            .onChange(of: hideInFullScreen) { _, _ in
                panelController.refreshPreferences()
            }

        Button {
            panelController.setLocked(!panelController.isLocked)
        } label: {
            Label(
                panelController.isLocked ? "解锁位置" : "锁定位置",
                systemImage: panelController.isLocked ? "lock.open" : "lock"
            )
        }

        Button {
            panelController.resetPosition()
        } label: {
            Label("重置位置", systemImage: "scope")
        }

        Divider()

        Button {
            panelController.setVisible(false, store: store, dataStore: dataStore)
        } label: {
            Label("暂时收起伙伴", systemImage: "eye.slash")
        }
    }

    private func interact() {
        interactionIndex += 1
        isInteracting = true
        speechRevision += 1
    }
}

private struct CompanionDragHandle: NSViewRepresentable {
    let controller: DesktopCompanionPanelController

    func makeNSView(context: Context) -> CompanionDragView {
        CompanionDragView(controller: controller)
    }

    func updateNSView(_ nsView: CompanionDragView, context: Context) {
        nsView.controller = controller
    }
}

private final class CompanionDragView: NSView {
    weak var controller: DesktopCompanionPanelController?

    init(controller: DesktopCompanionPanelController) {
        self.controller = controller
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        guard controller?.isLocked == false else { return }
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        controller?.performNativeDrag(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: controller?.isLocked == true ? .arrow : .openHand)
    }
}
