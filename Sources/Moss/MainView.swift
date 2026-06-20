import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today = "今天"
    case timeline = "时间线"
    case insights = "洞察"
    case archive = "归档"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .timeline: "waveform.path.ecg"
        case .insights: "sparkles"
        case .archive: "archivebox"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("selectedSection") private var selectedSectionRaw = AppSection.today.rawValue

    private var selection: Binding<AppSection?> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRaw) ?? .today },
            set: { selectedSectionRaw = ($0 ?? .today).rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MossTheme.sage)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Moss")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("专注岛")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 18)

                List(AppSection.allCases, selection: selection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .font(.system(size: 14, weight: .medium))
                        .tag(section)
                        .listRowBackground(
                            selection.wrappedValue == section
                                ? MossTheme.sage.opacity(0.14)
                                : Color.clear
                        )
                }
                .listStyle(.sidebar)

                SidebarFocusStatus()
                    .padding(14)
            }
            .navigationSplitViewColumnWidth(min: 185, ideal: 208, max: 240)
            .background(MossTheme.paper)
        } detail: {
            Group {
                switch selection.wrappedValue ?? .today {
                case .today: TodayView()
                case .timeline: TimelinePage()
                case .insights: InsightsView()
                case .archive: ArchiveView()
                case .settings: SettingsView()
                }
            }
            .background(MossTheme.paper)
        }
        .background(MossTheme.paper)
        .sheet(isPresented: $store.isReviewPresented) {
            ReviewView()
                .environmentObject(store)
        }
        .alert(
            "欢迎回来",
            isPresented: Binding(
                get: { store.wakeGapMessage != nil },
                set: { if !$0 { store.wakeGapMessage = nil } }
            )
        ) {
            Button("知道了") { store.wakeGapMessage = nil }
        } message: {
            Text(store.wakeGapMessage ?? "")
        }
        .overlay(alignment: .top) {
            if let message = store.transientMessage {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.transientMessage)
    }
}

private struct SidebarFocusStatus: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.phase == .idle {
                Label("岛屿安静着", systemImage: "leaf")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MossTheme.sage)
                Text("⌘⇧F 开始上一次任务")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    ProgressRing(progress: store.progress, lineWidth: 4)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.phase == .paused ? "暂停中" : store.phase == .breakTime ? "休息中" : "专注中")
                            .font(.caption.weight(.semibold))
                        Text(store.remaining.clockString)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Spacer()
                }
                Text(store.currentTaskTitle)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MossTheme.sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 5
    var tint: Color = MossTheme.sage

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.015, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
