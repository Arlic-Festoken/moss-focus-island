import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var panelController = NotchPanelController.shared
    @ObservedObject private var desktopWidgetController = DesktopWidgetPanelController.shared

    private var activeTasks: [FocusTask] {
        dataStore.startableTasks
    }

    private var preferredTask: FocusTask? {
        dataStore.preferredStartTask
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let notice = store.transientNotice {
                Label(notice.message, systemImage: "leaf.fill")
                    .font(MossTypography.font(11, weight: .semibold))
                    .foregroundStyle(MossTheme.sage)
                    .padding(.bottom, 10)
            }

            if store.phase == .idle {
                idleContent
            } else {
                activeContent
            }

            Divider()
                .padding(.vertical, 10)

            HStack {
                Button {
                    store.openMainWindow()
                } label: {
                    Label("打开 Moss", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                Spacer()
                Button {
                    desktopWidgetController.setVisible(
                        !desktopWidgetController.isVisible,
                        store: store,
                        dataStore: dataStore
                    )
                } label: {
                    Image(systemName: desktopWidgetController.isVisible ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                .help(desktopWidgetController.isVisible ? "隐藏桌面小组件" : "显示桌面小组件")
                .accessibilityLabel(desktopWidgetController.isVisible ? "隐藏桌面小组件" : "显示桌面小组件")
                Button {
                    panelController.setVisible(!panelController.isVisible, store: store)
                } label: {
                    Image(systemName: panelController.isVisible ? "eye.slash" : "eye")
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                .help(panelController.isVisible ? "隐藏专注岛" : "显示专注岛")
                .accessibilityLabel(panelController.isVisible ? "隐藏专注岛" : "显示专注岛")
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                .help("退出 Moss")
            }
            .font(MossTypography.font(12, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 330)
        .background(MossTheme.paper)
        .onAppear {
            MainWindowRouter.open = {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        .popover(isPresented: $store.interruptionNeedsReason) {
            InterruptionReasonPicker()
                .environmentObject(store)
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MossTheme.sage)
                VStack(alignment: .leading, spacing: 2) {
                    Text("岛屿安静着")
                        .font(.headline)
                    Text("今天完成 \(store.todayCompletedCount) 个专注段")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let first = preferredTask {
                Button {
                    store.startLastTask()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("开始上一次任务")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(first.title)
                                .font(MossTypography.font(14, weight: .semibold))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(MossTheme.sage, in: Circle())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(MossJellyPlainButtonStyle())

                HStack(spacing: 8) {
                    Button("先做 5 分钟") {
                        store.start(task: first, mode: .ignition)
                    }
                    .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot))

                    Menu("换个任务") {
                        ForEach(activeTasks) { task in
                            Button("\(task.category) · \(task.title)") {
                                store.start(task: task)
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            } else {
                Text("打开主页添加第一个任务。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 13) {
                ProgressRing(
                    progress: store.progress,
                    lineWidth: 5,
                    tint: store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: store.phase == .paused ? "pause.fill" : store.phase == .breakTime ? "cup.and.saucer.fill" : "leaf.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(phaseTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(store.phase == .breakTime ? MossTheme.apricot : MossTheme.sage)
                    Text(store.displayTime.clockString)
                        .font(MossTypography.font(25, weight: .bold))
                        .monospacedDigit()
                }
                Spacer()
                Text("\(store.todayCompletedCount) 段")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if store.phase != .breakTime {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.currentTaskTitle)
                        .font(MossTypography.font(14, weight: .semibold))
                    Text(store.currentCategory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(BreakPrompt.current)
                    .font(MossTypography.font(14, weight: .medium))
            }

            HStack(spacing: 8) {
                if store.phase == .preparing {
                    Button("取消开始") { store.cancelStart() }
                        .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick))
                } else if store.phase == .focusing {
                    Button("暂停") { store.pause() }
                        .buttonStyle(CapsuleButtonStyle())
                    Button("↗ 被打断") { store.beginOrReturnFromInterruption() }
                        .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot))
                    Button("结束") { store.requestEnd() }
                        .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick))
                } else if store.phase == .paused {
                    Button("继续") { store.resume() }
                        .buttonStyle(CapsuleButtonStyle(prominent: true))
                    Button("结束") { store.requestEnd() }
                        .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick))
                } else if store.phase == .breakTime {
                    Button("结束休息") { store.skipBreak() }
                        .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot, prominent: true, prominentForeground: .black))
                } else {
                    Button("完成记录") { store.presentReview() }
                        .buttonStyle(CapsuleButtonStyle(prominent: true))
                }
            }
        }
    }

    private var phaseTitle: String {
        switch store.phase {
        case .idle: "未开始"
        case .preparing: "进入状态中"
        case .focusing: "深度专注中"
        case .paused: "暂停中"
        case .breakTime: "休息一下"
        case .awaitingReview: "等待记录"
        }
    }
}

struct InterruptionReasonPicker: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("刚才因为什么离开？")
                .font(.headline)
            HStack(spacing: 8) {
                ForEach(InterruptionReason.allCases) { reason in
                    Button(reason.title) {
                        store.finishInterruption(reason: reason)
                    }
                    .buttonStyle(CapsuleButtonStyle())
                }
            }
        }
        .padding(16)
    }
}

enum BreakPrompt {
    static let prompts = [
        "看远处 20 秒",
        "站起来走两步",
        "不要打开短视频",
        "喝两口水",
        "闭眼，不看屏幕"
    ]

    static var current: String {
        let minute = Calendar.current.component(.minute, from: .now)
        return prompts[minute % prompts.count]
    }
}
