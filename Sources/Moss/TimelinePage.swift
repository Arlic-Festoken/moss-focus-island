import Charts
import SwiftUI

enum TimelineRange: String, CaseIterable, Identifiable {
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"

    var id: String { rawValue }
}

private struct PeriodPoint: Identifiable {
    let date: Date
    let duration: TimeInterval
    var id: Date { date }
}

struct TimelinePage: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var selectedDate = Date.now
    @AppStorage("timelineRange") private var rangeRaw = TimelineRange.day.rawValue

    private var range: TimelineRange {
        get { TimelineRange(rawValue: rangeRaw) ?? .day }
        nonmutating set { rangeRaw = newValue.rawValue }
    }

    private var rangeSelection: Binding<TimelineRange> {
        Binding(get: { range }, set: { range = $0 })
    }

    private var completedSessions: [FocusSession] {
        dataStore.sessions.filter { $0.status == .completed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("时间视图")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("从一天的波形，到一整年的投入。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("时间范围", selection: rangeSelection) {
                        ForEach(TimelineRange.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                    if range != .year {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }

                switch range {
                case .day:
                    dayView
                case .week:
                    weekView
                case .month:
                    monthView
                case .year:
                    FocusHeatmapView(sessions: dataStore.sessions)
                }
            }
            .padding(28)
            .frame(maxWidth: 1080, alignment: .leading)
        }
    }

    private var daySessions: [FocusSession] {
        sessions(from: selectedDate.dayStart, to: nextDay(after: selectedDate.dayStart))
    }

    private var dayView: some View {
        VStack(alignment: .leading, spacing: 14) {
            PeriodSummary(
                title: selectedDate.formatted(.dateTime.month().day().weekday(.wide)),
                sessions: daySessions
            )
            MossCard {
                if daySessions.isEmpty {
                    emptyState("这天没有专注记录", "岛屿会把每一段真实投入留在这里。")
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
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate.dayStart
    }

    private var weekPoints: [PeriodPoint] {
        (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return PeriodPoint(
                date: date,
                duration: sessions(from: date, to: nextDay(after: date)).reduce(0) { $0 + $1.actualFocusDuration }
            )
        }
    }

    private var weekView: some View {
        let weekSessions = sessions(
            from: weekStart,
            to: Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        )
        return VStack(alignment: .leading, spacing: 14) {
            PeriodSummary(
                title: "\(weekStart.formatted(.dateTime.month().day())) – \(weekPoints.last?.date.formatted(.dateTime.month().day()) ?? "")",
                sessions: weekSessions
            )
            MossCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("本周专注").font(.title3.bold())
                    Chart(weekPoints) { point in
                        BarMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("分钟", point.duration / 60)
                        )
                        .foregroundStyle(MossTheme.sage.gradient)
                        .cornerRadius(7)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) {
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text(minutes >= 60 ? "\(Int(minutes / 60))h" : "\(Int(minutes))m")
                                }
                            }
                        }
                    }
                    .frame(height: 260)
                }
            }
        }
    }

    private var monthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: selectedDate)
            ?? DateInterval(start: selectedDate.dayStart, duration: 30 * 86_400)
    }

    private var monthView: some View {
        let monthSessions = sessions(from: monthInterval.start, to: monthInterval.end)
        return VStack(alignment: .leading, spacing: 14) {
            PeriodSummary(
                title: selectedDate.formatted(.dateTime.year().month(.wide)),
                sessions: monthSessions
            )
            MossCard {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) {
                            Text($0)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(monthDays, id: \.date) { item in
                            VStack(spacing: 7) {
                                Text("\(Calendar.current.component(.day, from: item.date))")
                                    .font(.caption.weight(.semibold))
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(monthColor(duration: item.duration))
                                    .frame(height: 31)
                                    .overlay {
                                        if item.duration > 0 {
                                            Text(item.duration.compactDuration)
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .padding(5)
                            .background(
                                Calendar.current.isDateInToday(item.date)
                                    ? MossTheme.sage.opacity(0.09)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .help("\(item.date.formatted(.dateTime.month().day())) · \(item.duration.chineseDuration)")
                        }
                    }
                }
            }
        }
    }

    private var monthDays: [PeriodPoint] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: monthInterval.start)
        let mondayOffset = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayOffset, to: monthInterval.start) ?? monthInterval.start
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { return nil }
            return PeriodPoint(
                date: date,
                duration: sessions(from: date, to: nextDay(after: date)).reduce(0) { $0 + $1.actualFocusDuration }
            )
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

    private func sessions(from start: Date, to end: Date) -> [FocusSession] {
        completedSessions
            .filter { $0.startedAt >= start && $0.startedAt < end }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func nextDay(after date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private func monthColor(duration: TimeInterval) -> Color {
        switch duration {
        case ...0: Color.primary.opacity(0.045)
        case ..<(25 * 60): MossTheme.sage.opacity(0.28)
        case ..<(60 * 60): MossTheme.sage.opacity(0.48)
        case ..<(120 * 60): MossTheme.sage.opacity(0.68)
        default: MossTheme.sage
        }
    }

    private func legendItem(_ text: String, color: Color, symbol: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: symbol).foregroundStyle(color) }
    }

    private func emptyState(_ title: String, _ description: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: "waveform.path",
            description: Text(description)
        )
        .frame(minHeight: 260)
    }
}

private struct PeriodSummary: View {
    let title: String
    let sessions: [FocusSession]

    private var total: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualFocusDuration }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text("\(sessions.count) 段专注")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(total.chineseDuration)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(MossTheme.sage)
        }
        .padding(16)
        .background(MossTheme.card, in: RoundedRectangle(cornerRadius: 17))
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
                    Text(session.taskTitle).font(.headline)
                    Spacer()
                    Text(session.actualFocusDuration.compactDuration)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MossTheme.sage)
                }
                HStack(spacing: 10) {
                    Text(session.projectTitle)
                    Label(session.timerActivity.title, systemImage: session.timerActivity.icon)
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
                            .frame(
                                width: session.plannedDuration > 0
                                    ? proxy.size.width * min(1, max(0.05, session.actualFocusDuration / session.plannedDuration))
                                    : proxy.size.width
                            )
                    }
                }
                .frame(height: 7)
            }
            .padding(.bottom, isLast ? 0 : 22)
        }
    }
}
