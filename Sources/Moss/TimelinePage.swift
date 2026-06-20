import SwiftUI

struct TimelinePage: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var selectedDate = Date.now

    private var daySessions: [FocusSession] {
        let start = Calendar.current.startOfDay(for: selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return dataStore.sessions
            .filter { $0.startedAt >= start && $0.startedAt < end }
            .sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("学习波形")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("看见一天是怎样流过的，而不只是一个总数。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }

                MossCard {
                    if daySessions.isEmpty {
                        ContentUnavailableView(
                            "这天没有专注记录",
                            systemImage: "waveform.path",
                            description: Text("岛屿会把每一段真实投入留在这里。")
                        )
                        .frame(minHeight: 260)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(daySessions.enumerated()), id: \.element.id) { index, session in
                                DetailedTimelineRow(session: session, isLast: index == daySessions.count - 1)
                            }
                        }
                    }
                }

                legend
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private var legend: some View {
        HStack(spacing: 20) {
            legendItem("完成", color: MossTheme.sage, symbol: "line.diagonal")
            legendItem("五分钟点火", color: MossTheme.apricot, symbol: "ellipsis")
            legendItem("出现暂停", color: MossTheme.brick, symbol: "pause.fill")
            legendItem("无中断完成", color: MossTheme.mint, symbol: "leaf.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendItem(_ text: String, color: Color, symbol: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }
}

private struct DetailedTimelineRow: View {
    let session: FocusSession
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(spacing: 0) {
                Circle()
                    .fill(session.mode == .ignition ? MossTheme.apricot : MossTheme.sage)
                    .frame(width: 12, height: 12)
                    .overlay {
                        if session.pausedDuration < 10 && session.status == .completed {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.white)
                        }
                    }
                if !isLast {
                    Rectangle()
                        .fill(MossTheme.sage.opacity(0.16))
                        .frame(width: 2, height: 72)
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(session.startedAt.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(session.taskTitle)
                        .font(.headline)
                    Spacer()
                    Text(session.actualFocusDuration.compactDuration)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MossTheme.sage)
                }
                HStack(spacing: 10) {
                    Text(session.category)
                    if session.mode == .ignition {
                        Label("点火", systemImage: "spark")
                    }
                    if session.pausedDuration >= 10 {
                        Label("暂停 \(session.pausedDuration.compactDuration)", systemImage: "pause")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MossTheme.sage.opacity(0.08))
                        Capsule()
                            .fill(session.mode == .ignition ? MossTheme.apricot : MossTheme.sage)
                            .frame(width: proxy.size.width * min(1, max(0.05, session.actualFocusDuration / max(1, session.plannedDuration))))
                    }
                }
                .frame(height: 7)
            }
            .padding(.bottom, isLast ? 0 : 22)
        }
    }
}
