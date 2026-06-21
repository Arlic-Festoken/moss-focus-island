import Charts
import SwiftUI

struct DailyChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
}

struct InsightsView: View {
    @EnvironmentObject private var dataStore: DataStore

    private var completed: [FocusSession] {
        dataStore.sessions.filter { $0.status == .completed }
    }

    private var metrics: DailyMetrics {
        InsightEngine.todayMetrics(
            sessions: dataStore.sessions,
            interruptions: dataStore.interruptions
        )
    }

    private var lastSevenDays: [DailyChartPoint] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date.now) ?? .now
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let seconds = completed
                .filter { $0.startedAt >= start && $0.startedAt < end }
                .reduce(0) { $0 + $1.actualFocusDuration }
            return DailyChartPoint(date: start, minutes: seconds / 60)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("洞察")
                        .font(MossTypography.font(30, weight: .bold))
                    Text("只保留能改变明天行动的指标。")
                        .foregroundStyle(.secondary)
                }

                metricStrip

                FocusHeatmapView(sessions: dataStore.sessions)

                HStack(alignment: .top, spacing: 18) {
                    weeklyChart
                        .frame(maxWidth: .infinity)
                    categoryGarden
                        .frame(width: 310)
                }

                MossCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("本周观察")
                            .font(.title3.bold())
                        ForEach(weeklyObservations, id: \.self) { observation in
                            Label(observation, systemImage: "leaf")
                                .font(MossTypography.font(14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1080, alignment: .leading)
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 12) {
            MetricTile(title: "总专注", value: completed.reduce(0) { $0 + $1.actualFocusDuration }.compactDuration, icon: "timer")
            MetricTile(title: "开始次数", value: "\(dataStore.sessions.count)", icon: "play.fill")
            MetricTile(title: "完成率", value: percent(completed.isEmpty ? 0 : Double(completed.count) / Double(max(1, dataStore.sessions.count))), icon: "checkmark")
            MetricTile(title: "预估偏差", value: "\(Int(abs(1 - metrics.planAccuracy) * 100))%", icon: "arrow.left.arrow.right")
            MetricTile(title: "中断回流", value: percent(metrics.interruptionReturnRate), icon: "arrow.uturn.forward")
        }
    }

    private var weeklyChart: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("最近 7 天")
                    .font(.title3.bold())
                Chart(lastSevenDays) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("分钟", point.minutes)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MossTheme.sage, MossTheme.mint],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(7)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes / 60))h")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 250)
            }
        }
    }

    private var categoryGarden: some View {
        let grouped = Dictionary(grouping: completed, by: \.category)
        let top = grouped
            .map { (category: $0.key, seconds: $0.value.reduce(0) { $0 + $1.actualFocusDuration }) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(5)

        return MossCard {
            VStack(alignment: .leading, spacing: 15) {
                Text("学科花园")
                    .font(.title3.bold())
                Text("只生长，不因停顿枯萎。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if top.isEmpty {
                    Image(systemName: "leaf")
                        .font(.system(size: 54, weight: .ultraLight))
                        .foregroundStyle(MossTheme.sage.opacity(0.3))
                        .frame(maxWidth: .infinity, minHeight: 190)
                } else {
                    ForEach(Array(top), id: \.category) { item in
                        HStack {
                            CategoryGlyph(category: item.category)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.category)
                                    .font(MossTypography.font(13, weight: .semibold))
                                Text(item.seconds.compactDuration)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<min(5, max(1, Int(item.seconds / 1500))), id: \.self) { _ in
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 10))
                                }
                            }
                            .foregroundStyle(MossTheme.sage)
                        }
                    }
                }
            }
        }
    }

    private var weeklyObservations: [String] {
        guard !completed.isEmpty else {
            return ["完成三段专注后，这里会开始出现有依据的反馈。"]
        }
        let grouped = Dictionary(grouping: completed, by: \.category)
        let top = grouped.max { $0.value.count < $1.value.count }?.key ?? "未分类"
        let lateCount = completed.filter { Calendar.current.component(.hour, from: $0.startedAt) >= 21 }.count
        return [
            "投入最多的是“\(top)”，它已经形成稳定轨迹。",
            lateCount > completed.count / 2 ? "你的深度投入更多发生在晚上 21:00 后。" : "你的专注时段分布比较均匀。",
            metrics.planAccuracy > 1.25 ? "实际用时常高于预估，任务颗粒度可以更小。" : "近期任务预估与实际相对接近。"
        ]
    }

    private func percent(_ value: Double) -> String {
        "\(Int((min(1, max(0, value)) * 100).rounded()))%"
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(MossTheme.sage)
            Text(value)
                .font(MossTypography.font(21, weight: .bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MossTheme.card, in: RoundedRectangle(cornerRadius: 17))
    }
}
