import SwiftUI

private struct HeatmapDay: Identifiable {
    let date: Date
    let duration: TimeInterval
    let isFuture: Bool

    var id: Date { date }
}

private struct FocusHeatmapModel {
    let days: [HeatmapDay]
    let totalDuration: TimeInterval
    let activeDays: Int
    let currentStreak: Int
    let longestStreak: Int

    init(sessions: [FocusSession], now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysToSaturday = 7 - weekday
        let gridEnd = calendar.date(byAdding: .day, value: daysToSaturday, to: today) ?? today
        let gridStart = calendar.date(byAdding: .day, value: -370, to: gridEnd) ?? today

        let completed = sessions.filter { $0.status == .completed }
        let grouped = Dictionary(grouping: completed) {
            calendar.startOfDay(for: $0.startedAt)
        }
        let durations = grouped.mapValues {
            $0.reduce(0) { $0 + $1.actualFocusDuration }
        }

        days = (0..<371).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            return HeatmapDay(
                date: date,
                duration: durations[date] ?? 0,
                isFuture: date > today
            )
        }

        let yearStart = calendar.date(byAdding: .day, value: -364, to: today) ?? today
        let yearDurations = durations.filter { $0.key >= yearStart && $0.key <= today }
        totalDuration = yearDurations.values.reduce(0, +)
        activeDays = yearDurations.values.filter { $0 > 0 }.count

        var current = 0
        var cursor = today
        while (durations[cursor] ?? 0) > 0 {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        currentStreak = current

        var longest = 0
        var running = 0
        for offset in 0..<365 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: yearStart) else {
                continue
            }
            if (durations[date] ?? 0) > 0 {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }
        longestStreak = longest
    }
}

struct FocusHeatmapView: View {
    let sessions: [FocusSession]
    var title = "年度专注图"
    var subtitle = "每一格是一天，专注越久，颜色越深。"
    var referenceDate = Date.now
    @State private var hoveredDay: Date?

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3
    private let weekdayWidth: CGFloat = 22

    var body: some View {
        let model = FocusHeatmapModel(sessions: sessions, now: referenceDate)
        MossCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3.bold())
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let hovered = hoveredDay,
                       let day = model.days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hovered) }) {
                        Text(dayTooltip(day))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(MossTheme.sage)
                            .transition(.opacity)
                    } else {
                        Text("最近 365 天")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 0) {
                    HeatmapStat(value: model.totalDuration.chineseDuration, label: "累计专注")
                    Divider().frame(height: 42)
                    HeatmapStat(value: "\(model.activeDays) 天", label: "活跃天数")
                    Divider().frame(height: 42)
                    HeatmapStat(value: "\(model.currentStreak) 天", label: "当前连续")
                    Divider().frame(height: 42)
                    HeatmapStat(value: "\(model.longestStreak) 天", label: "最长连续")
                }
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 15))

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        monthLabels(model)
                        HStack(alignment: .top, spacing: 7) {
                            weekdayLabels
                            heatmapGrid(model)
                        }
                    }
                    .padding(.bottom, 2)
                }

                HStack(spacing: 6) {
                    Spacer()
                    Text("少")
                    ForEach(0...5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: level))
                            .frame(width: cellSize, height: cellSize)
                    }
                    Text("多")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func monthLabels(_ model: FocusHeatmapModel) -> some View {
        HStack(spacing: cellSpacing) {
            Color.clear.frame(width: weekdayWidth + 7, height: 14)
            ForEach(0..<53, id: \.self) { week in
                let date = model.days[week * 7].date
                let previous = week > 0 ? model.days[(week - 1) * 7].date : nil
                let month = Calendar.current.component(.month, from: date)
                let previousMonth = previous.map { Calendar.current.component(.month, from: $0) }
                Text(previousMonth != month ? "\(month)月" : "")
                    .font(MossTypography.font(9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: cellSize, alignment: .leading)
            }
        }
    }

    private var weekdayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<7, id: \.self) { weekday in
                Text(weekday == 1 ? "一" : weekday == 3 ? "三" : weekday == 5 ? "五" : "")
                    .font(MossTypography.font(8))
                    .foregroundStyle(.secondary)
                    .frame(width: weekdayWidth, height: cellSize, alignment: .trailing)
            }
        }
    }

    private func heatmapGrid(_ model: FocusHeatmapModel) -> some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(0..<53, id: \.self) { week in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { weekday in
                        let day = model.days[week * 7 + weekday]
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(day.isFuture ? Color.clear : color(for: intensity(for: day.duration)))
                            .frame(width: cellSize, height: cellSize)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(
                                        hoveredDay.map { Calendar.current.isDate($0, inSameDayAs: day.date) } == true
                                            ? MossTheme.sage.opacity(0.85)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .onHover { inside in
                                hoveredDay = inside && !day.isFuture ? day.date : nil
                            }
                            .help(day.isFuture ? "" : dayTooltip(day))
                    }
                }
            }
        }
    }

    private func intensity(for duration: TimeInterval) -> Int {
        switch duration {
        case ...0: 0
        case ..<(25 * 60): 1
        case ..<(60 * 60): 2
        case ..<(120 * 60): 3
        case ..<(180 * 60): 4
        default: 5
        }
    }

    private func color(for level: Int) -> Color {
        guard level > 0 else { return Color.primary.opacity(0.055) }
        let opacity = [0.0, 0.22, 0.40, 0.58, 0.78, 1.0][min(5, level)]
        return MossTheme.sage.opacity(opacity)
    }

    private func dayTooltip(_ day: HeatmapDay) -> String {
        let date = day.date.formatted(.dateTime.year().month().day().weekday(.abbreviated))
        return day.duration > 0
            ? "\(date) · \(day.duration.chineseDuration)"
            : "\(date) · 没有记录"
    }
}

private struct HeatmapStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(MossTypography.font(15, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
