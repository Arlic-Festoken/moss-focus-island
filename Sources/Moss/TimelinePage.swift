import Charts
import SwiftUI

enum TimelineRange: String, CaseIterable, Identifiable {
    case all = "全部"
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"

    var id: String { rawValue }
}

private struct HistoryDayGroup: Identifiable {
    let date: Date
    let sessions: [FocusSession]
    var id: Date { date }
    var completedDuration: TimeInterval {
        sessions.filter { $0.status == .completed }.reduce(0) { $0 + $1.actualFocusDuration }
    }
}

private struct HistoryChartPoint: Identifiable {
    let date: Date
    let duration: TimeInterval
    var id: Date { date }
}

struct TimelinePage: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var selectedDate = Date.now
    @State private var query = ""
    @State private var groupRaw = ""
    @State private var titleFilter = ""
    @State private var statusRaw = HistoryStatusFilter.all.rawValue
    @State private var selectedTitle: TitleMetric?
    @State private var analytics = FocusAnalyticsSnapshot(sessions: [])
    @AppStorage("timelineRange") private var rangeRaw = TimelineRange.all.rawValue

    private var range: TimelineRange {
        get { TimelineRange(rawValue: rangeRaw) ?? .all }
        nonmutating set { rangeRaw = newValue.rawValue }
    }

    private var historyFilter: HistoryFilter {
        HistoryFilter(
            query: query,
            group: TitleGroup(rawValue: groupRaw),
            title: titleFilter.isEmpty ? nil : titleFilter,
            status: HistoryStatusFilter(rawValue: statusRaw) ?? .all
        )
    }

    private var displayedSessions: [FocusSession] {
        let matching = dataStore.sessions.filter(historyFilter.matches)
        guard let interval = selectedInterval else {
            return matching.sorted { $0.startedAt > $1.startedAt }
        }
        return matching
            .filter { $0.startedAt >= interval.start && $0.startedAt < interval.end }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var selectedInterval: DateInterval? {
        let calendar = Calendar.current
        return switch range {
        case .all: nil
        case .day:
            DateInterval(start: selectedDate.dayStart, end: calendar.date(byAdding: .day, value: 1, to: selectedDate.dayStart) ?? selectedDate)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: selectedDate)
        case .month:
            calendar.dateInterval(of: .month, for: selectedDate)
        case .year:
            calendar.dateInterval(of: .year, for: selectedDate)
        }
    }

    private func dayGroups(for sessions: [FocusSession]) -> [HistoryDayGroup] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.startedAt) }
            .map { date, items in
                HistoryDayGroup(date: date, sessions: items.sorted { $0.startedAt > $1.startedAt })
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        let visibleSessions = displayedSessions
        let visibleAnalytics = FocusAnalyticsSnapshot(sessions: visibleSessions)
        let visibleDayGroups = dayGroups(for: visibleSessions)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                filterPanel
                summaryStrip(visibleAnalytics)

                if range == .year {
                    FocusHeatmapView(
                        sessions: visibleSessions,
                        title: "\(selectedDate.formatted(.dateTime.year())) 年度轨迹",
                        subtitle: activeFilterDescription,
                        referenceDate: selectedDate
                    )
                } else if range == .week || range == .month {
                    historyChart(chartPoints(for: visibleSessions))
                }

                historyList(visibleDayGroups)
            }
            .padding(28)
            .frame(maxWidth: 1080, alignment: .leading)
        }
        .sheet(item: $selectedTitle) { metric in
            TitleDetailView(metric: metric)
        }
        .onReceive(dataStore.$sessions) { sessions in
            analytics = FocusAnalyticsSnapshot(sessions: sessions)
        }
    }

    private var header: some View {
        MossPageHeader(
            eyebrow: "Focus Archive",
            title: "专注历史",
            subtitle: "按领域、项目和状态重走每一段已经兑现的时间。"
        ) {
            Picker("时间范围", selection: Binding(get: { range }, set: { range = $0 })) {
                ForEach(TimelineRange.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)
            .frame(width: 310)
        }
    }

    private var filterPanel: some View {
        MossCard(padding: 14, kind: .quiet) {
            VStack(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { primaryFilters }
                    VStack(spacing: 10) { primaryFilters }
                }
                if range != .all {
                    HStack(spacing: 8) {
                        TimelineNavigationButton(
                            systemName: "chevron.left",
                            accessibilityLabel: "上一个时间段"
                        ) {
                            moveSelection(-1)
                        }
                        TimelineDateSelector(selection: $selectedDate)
                        TimelineNavigationButton(
                            systemName: "chevron.right",
                            accessibilityLabel: "下一个时间段"
                        ) {
                            moveSelection(1)
                        }
                        Text(periodTitle)
                            .font(MossTypography.font(12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("清除筛选") { clearFilters() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(MossTheme.sage)
                    }
                } else if hasActiveFilters {
                    HStack {
                        Spacer()
                        Button("清除筛选") { clearFilters() }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(MossTheme.sage)
                    }
                }
            }
        }
    }

    @ViewBuilder private var primaryFilters: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索 title、项目或心得", text: $query)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        .frame(minWidth: 210, maxWidth: .infinity)

        TimelineFilterMenu(
            title: TitleGroup(rawValue: groupRaw)?.title ?? "全部分区",
            accessibilityLabel: "分区筛选，当前为 \(TitleGroup(rawValue: groupRaw)?.title ?? "全部分区")",
            isActive: !groupRaw.isEmpty,
            width: 132
        ) {
            Button {
                groupRaw = ""
            } label: {
                Label("全部分区", systemImage: groupRaw.isEmpty ? "checkmark" : "square.grid.2x2")
            }
            ForEach(TitleGroup.allCases) { group in
                Button {
                    groupRaw = group.rawValue
                } label: {
                    Label(
                        group.title,
                        systemImage: groupRaw == group.rawValue ? "checkmark" : group.symbol
                    )
                }
            }
        }

        TimelineFilterMenu(
            title: titleFilter.isEmpty ? "全部 title" : titleFilter,
            accessibilityLabel: "Title 筛选，当前为 \(titleFilter.isEmpty ? "全部 title" : titleFilter)",
            isActive: !titleFilter.isEmpty,
            width: 132
        ) {
            Button {
                titleFilter = ""
            } label: {
                Label("全部 title", systemImage: titleFilter.isEmpty ? "checkmark" : "text.quote")
            }
            ForEach(analytics.titleMetrics) { metric in
                Button {
                    titleFilter = metric.title
                } label: {
                    Label(
                        metric.title,
                        systemImage: titleFilter == metric.title ? "checkmark" : "text.quote"
                    )
                }
            }
        }

        TimelineFilterMenu(
            title: HistoryStatusFilter(rawValue: statusRaw)?.title ?? HistoryStatusFilter.all.title,
            accessibilityLabel: "状态筛选，当前为 \(HistoryStatusFilter(rawValue: statusRaw)?.title ?? HistoryStatusFilter.all.title)",
            isActive: statusRaw != HistoryStatusFilter.all.rawValue,
            width: 118
        ) {
            ForEach(HistoryStatusFilter.allCases) { status in
                Button {
                    statusRaw = status.rawValue
                } label: {
                    Label(
                        status.title,
                        systemImage: statusRaw == status.rawValue ? "checkmark" : "circle"
                    )
                }
            }
        }
    }

    private func summaryStrip(_ snapshot: FocusAnalyticsSnapshot) -> some View {
        MossCard(padding: 14, kind: .quiet) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { historyMetrics(snapshot) }
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 13
                ) {
                    historyMetrics(snapshot)
                }
            }
        }
    }

    @ViewBuilder
    private func historyMetrics(_ snapshot: FocusAnalyticsSnapshot) -> some View {
        MossMetric(
            value: snapshot.totalFocus.compactDuration,
            label: "有效专注",
            symbol: "timer"
        )
        MossMetric(
            value: "\(snapshot.completionCount) 段",
            label: "完成",
            symbol: "checkmark.circle.fill",
            tint: MossTheme.mint
        )
        MossMetric(
            value: "\(snapshot.abandonedCount) 段",
            label: "中途结束",
            symbol: "arrow.uturn.backward.circle",
            tint: MossTheme.brick
        )
        MossMetric(
            value: "\(snapshot.activeDays) 天",
            label: "活跃",
            symbol: "calendar",
            tint: TitleGroup.exploration.color
        )
    }

    private func historyChart(_ points: [HistoryChartPoint]) -> some View {
        MossCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(range == .week ? "一周波形" : "本月波形")
                        .font(MossTypography.editorial(20, weight: .semibold))
                    Spacer()
                    Text(activeFilterDescription).font(.caption).foregroundStyle(.secondary)
                }
                Chart(points) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("分钟", point.duration / 60)
                    )
                    .foregroundStyle(MossTheme.sage.gradient)
                    .cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: range == .week ? 7 : 10)) {
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(minutes >= 60 ? "\(Int(minutes / 60))h" : "\(Int(minutes))m")
                            }
                        }
                    }
                }
                .frame(height: 210)
            }
        }
    }

    private func chartPoints(for sessions: [FocusSession]) -> [HistoryChartPoint] {
        guard let interval = selectedInterval else { return [] }
        let calendar = Calendar.current
        let numberOfDays = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        let completedByDay = Dictionary(grouping: sessions.filter { $0.status == .completed }) {
            calendar.startOfDay(for: $0.startedAt)
        }
        return (0..<numberOfDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return HistoryChartPoint(
                date: date,
                duration: completedByDay[date]?.reduce(0) { $0 + $1.actualFocusDuration } ?? 0
            )
        }
    }

    @ViewBuilder private func historyList(_ groups: [HistoryDayGroup]) -> some View {
        if groups.isEmpty {
            MossCard(kind: .quiet) {
                ContentUnavailableView(
                    "没有匹配的专注记录",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("调整时间范围或筛选条件后再看看。")
                )
                .frame(minHeight: 260)
            }
        } else {
            LazyVStack(spacing: 14) {
                ForEach(groups) { group in
                    HistoryDayCard(group: group) { title in
                        selectedTitle = analytics.metric(for: title)
                    }
                }
            }
        }
    }

    private var activeFilterDescription: String {
        var parts: [String] = []
        if let group = TitleGroup(rawValue: groupRaw) { parts.append(group.title) }
        if !titleFilter.isEmpty { parts.append(titleFilter) }
        if let status = HistoryStatusFilter(rawValue: statusRaw), status != .all { parts.append(status.title) }
        if !query.isEmpty { parts.append("“\(query)”") }
        return parts.isEmpty ? "全部有效专注" : parts.joined(separator: " · ")
    }

    private var hasActiveFilters: Bool {
        !query.isEmpty || !groupRaw.isEmpty || !titleFilter.isEmpty || statusRaw != HistoryStatusFilter.all.rawValue
    }

    private var periodTitle: String {
        guard let interval = selectedInterval else { return "全部历史" }
        return switch range {
        case .all: "全部历史"
        case .day: interval.start.formatted(.dateTime.year().month().day().weekday(.wide))
        case .week: "\(interval.start.formatted(.dateTime.month().day())) – \(interval.end.addingTimeInterval(-1).formatted(.dateTime.month().day()))"
        case .month: selectedDate.formatted(.dateTime.year().month(.wide))
        case .year: selectedDate.formatted(.dateTime.year())
        }
    }

    private func moveSelection(_ direction: Int) {
        let component: Calendar.Component
        switch range {
        case .all: return
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        selectedDate = Calendar.current.date(byAdding: component, value: direction, to: selectedDate) ?? selectedDate
    }

    private func clearFilters() {
        query = ""
        groupRaw = ""
        titleFilter = ""
        statusRaw = HistoryStatusFilter.all.rawValue
    }
}

private struct HistoryDayCard: View {
    let group: HistoryDayGroup
    let onSelectTitle: (String) -> Void

    var body: some View {
        MossCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.date.formatted(.dateTime.year().month().day().weekday(.wide)))
                            .font(MossTypography.editorial(16, weight: .semibold))
                        Text("\(group.sessions.count) 条记录")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("+\(Int(group.completedDuration / 60)) XP", systemImage: "sparkles")
                        .font(MossTypography.font(11, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                    Text(group.completedDuration.compactDuration)
                        .font(MossTypography.font(16, weight: .bold))
                        .frame(width: 72, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(MossTheme.sage.opacity(0.045))

                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                    HistorySessionRow(session: session, onSelectTitle: onSelectTitle)
                    if index < group.sessions.count - 1 {
                        Divider().padding(.leading, 70).opacity(0.48)
                    }
                }
            }
        }
    }
}

private struct HistorySessionRow: View {
    let session: FocusSession
    let onSelectTitle: (String) -> Void

    private var profile: TitleProfile { .resolve(session.taskTitle) }

    var body: some View {
        HStack(spacing: 14) {
            Text(session.startedAt.formatted(.dateTime.hour().minute()))
                .font(MossTypography.font(12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Image(systemName: profile.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(profile.group.color)
                .frame(width: 30, height: 30)
                .background(profile.group.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Button { onSelectTitle(session.taskTitle) } label: {
                    Text(session.taskTitle)
                        .font(MossTypography.font(14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(profile.group.title)
                    if !session.note.isEmpty { Text(session.note).lineLimit(1) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            SessionStatusBadge(status: session.status)
            Text(session.actualFocusDuration.compactDuration)
                .font(MossTypography.font(13, weight: .bold))
                .foregroundStyle(session.status == .abandoned ? .secondary : profile.group.color)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .opacity(session.status == .abandoned ? 0.68 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.taskTitle)，\(session.actualFocusDuration.chineseDuration)，\(session.status == .abandoned ? "中途放弃" : "已完成")")
    }
}
