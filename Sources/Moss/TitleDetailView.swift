import Charts
import SwiftUI

struct TitleIdentityLabel: View {
    let profile: TitleProfile
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: profile.symbol)
            Text(profile.title)
                .lineLimit(1)
        }
        .font(MossTypography.font(compact ? 11 : 13, weight: .semibold))
        .foregroundStyle(profile.group.color)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(profile.group.color.opacity(0.11), in: Capsule())
        .overlay(Capsule().stroke(profile.group.color.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.group.title)，\(profile.title)")
    }
}

struct SessionStatusBadge: View {
    let status: SessionStatus

    var body: some View {
        Label(
            status == .abandoned ? "中途放弃" : "已完成",
            systemImage: status == .abandoned ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill"
        )
        .font(MossTypography.font(10, weight: .semibold))
        .foregroundStyle(status == .abandoned ? MossTheme.brick : MossTheme.sage)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            (status == .abandoned ? MossTheme.brick : MossTheme.sage).opacity(0.1),
            in: Capsule()
        )
    }
}

private struct CumulativeFocusPoint: Identifiable {
    let date: Date
    let duration: TimeInterval
    var id: Date { date }
}

struct TitleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let metric: TitleMetric

    private var cumulativePoints: [CumulativeFocusPoint] {
        var running: TimeInterval = 0
        return metric.completedSessions
            .sorted { $0.startedAt < $1.startedAt }
            .map { session in
                running += session.actualFocusDuration
                return CumulativeFocusPoint(date: session.startedAt, duration: running)
            }
    }

    private var nextMasteryText: String {
        switch metric.mastery {
        case .seed:
            return "距离萌芽还差 \(max(0, 2 * 3_600 - metric.totalDuration).compactDuration)"
        case .sprout:
            return "距离林地还差 \(max(0, 10 * 3_600 - metric.totalDuration).compactDuration)"
        case .grove:
            return "距离地标还差 \(max(0, 25 * 3_600 - metric.totalDuration).compactDuration)"
        case .landmark:
            return "已成为专注岛地标"
        }
    }

    var body: some View {
        let points = cumulativePoints
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        TitleIdentityLabel(profile: metric.profile)
                        Text(metric.title)
                            .font(MossTypography.font(30, weight: .bold))
                        Text(metric.profile.narrative)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("完成") { dismiss() }
                        .buttonStyle(CapsuleButtonStyle(tint: metric.profile.group.color))
                }

                masteryHero

                MossCard {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("成长曲线").font(.title3.bold())
                            Spacer()
                            Text(metric.totalDuration.chineseDuration)
                                .font(MossTypography.font(14, weight: .bold))
                                .foregroundStyle(metric.profile.group.color)
                        }
                        if points.isEmpty {
                            ContentUnavailableView("还没有有效专注", systemImage: "chart.xyaxis.line")
                                .frame(height: 190)
                        } else {
                            Chart(points) { point in
                                AreaMark(
                                    x: .value("日期", point.date),
                                    y: .value("小时", point.duration / 3_600)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [metric.profile.group.color.opacity(0.32), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                LineMark(
                                    x: .value("日期", point.date),
                                    y: .value("小时", point.duration / 3_600)
                                )
                                .foregroundStyle(metric.profile.group.color)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                                    AxisValueLabel {
                                        if let hours = value.as(Double.self) { Text("\(Int(hours))h") }
                                    }
                                }
                            }
                            .frame(height: 220)
                        }
                    }
                }

                FocusHeatmapView(
                    sessions: metric.sessions,
                    title: "\(metric.title) 的年度轨迹",
                    subtitle: "只显示这个 title 的有效专注。"
                )

                MossCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("完整记录").font(.title3.bold())
                            Spacer()
                            Text("\(metric.sessions.count) 条")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 12)
                        ForEach(Array(metric.sessions.enumerated()), id: \.element.id) { index, session in
                            TitleSessionRow(session: session, profile: metric.profile)
                            if index < metric.sessions.count - 1 { Divider().opacity(0.45) }
                        }
                    }
                }
            }
            .padding(26)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .background(MossTheme.paper)
        .frame(minWidth: 680, minHeight: 620)
    }

    private var masteryHero: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().fill(metric.profile.group.color.opacity(0.12))
                Circle().stroke(metric.profile.group.color.opacity(0.20), lineWidth: 1)
                Image(systemName: metric.mastery.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(metric.profile.group.color)
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 5) {
                Text(metric.mastery.title)
                    .font(MossTypography.font(22, weight: .bold))
                Text(nextMasteryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let first = metric.firstDate, let last = metric.lastDate {
                    Text("\(first.formatted(.dateTime.year().month().day())) – \(last.formatted(.dateTime.year().month().day()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            detailStat("累计", metric.totalDuration.chineseDuration)
            detailStat("完成", "\(metric.completedCount) 段")
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [metric.profile.group.color.opacity(0.16), MossTheme.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    private func detailStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(value)
                .font(MossTypography.font(17, weight: .bold))
                .monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct TitleSessionRow: View {
    let session: FocusSession
    let profile: TitleProfile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: profile.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(profile.group.color)
                .frame(width: 30, height: 30)
                .background(profile.group.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(session.startedAt.formatted(.dateTime.year().month().day().hour().minute()))
                    .font(MossTypography.font(12, weight: .medium))
                if !session.note.isEmpty {
                    Text(session.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            SessionStatusBadge(status: session.status)
            Text(session.actualFocusDuration.compactDuration)
                .font(MossTypography.font(13, weight: .bold))
                .foregroundStyle(session.status == .abandoned ? .secondary : profile.group.color)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .opacity(session.status == .abandoned ? 0.68 : 1)
    }
}
