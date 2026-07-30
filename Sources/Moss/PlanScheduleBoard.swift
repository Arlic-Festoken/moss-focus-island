import SwiftUI

struct PlanScheduleBoard: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onCreate: (Date, Int) -> Void
    let onEdit: (PlanEntry) -> Void

    @State private var weekStart = PlanScheduleBoard.startOfWeek(containing: .now)
    @State private var weekDragOffset: CGFloat = 0

    private let hourGutterWidth: CGFloat = 54
    private let hourHeight: CGFloat = 64
    private let startHour = 6
    private let endHour = 24

    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = 2
        return value
    }

    private var days: [Date] {
        (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    private var weekEnd: Date {
        calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    private var weekPlans: [PlanEntry] {
        dataStore.plans.filter {
            $0.scheduledAt >= weekStart && $0.scheduledAt < weekEnd
        }
    }

    private var placedPlans: [PlanEntry] {
        weekPlans.filter { isPlacedOnTimeline($0) }
    }

    private var waitingPlans: [PlanEntry] {
        weekPlans.filter { !isPlacedOnTimeline($0) && $0.status == .planned }
    }

    private var plannedMinutes: Int {
        weekPlans
            .filter { $0.status == .planned }
            .reduce(0) { $0 + $1.estimatedMinutes }
    }

    var body: some View {
        GeometryReader { proxy in
            let dayWidth = max(
                112,
                (proxy.size.width - hourGutterWidth - 2) / 7
            )

            VStack(spacing: 0) {
                scheduleHeader

                if !waitingPlans.isEmpty {
                    waitingStrip
                }

                Divider().opacity(0.48)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        hourGutter

                        ForEach(days, id: \.self) { day in
                            ScheduleDayColumn(
                                day: day,
                                plans: placedPlans.filter {
                                    calendar.isDate($0.scheduledAt, inSameDayAs: day)
                                },
                                allDayLoadMinutes: weekPlans
                                    .filter {
                                        calendar.isDate($0.scheduledAt, inSameDayAs: day)
                                            && $0.status == .planned
                                    }
                                    .reduce(0) { $0 + $1.estimatedMinutes },
                                width: dayWidth,
                                hourHeight: hourHeight,
                                startHour: startHour,
                                endHour: endHour,
                                onSelectRange: { startMinute, duration in
                                    createPlan(
                                        on: day,
                                        startMinute: startMinute,
                                        duration: duration
                                    )
                                },
                                onMove: movePlan,
                                onEdit: onEdit
                            )
                        }
                    }
                    .frame(
                        width: hourGutterWidth + dayWidth * 7,
                        alignment: .topLeading
                    )
                }
                .background(MossTheme.card.opacity(0.18))
            }
        }
    }

    private var scheduleHeader: some View {
        HStack(spacing: 14) {
            Button {
                moveWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
            .help("上一周")

            VStack(alignment: .leading, spacing: 3) {
                Text(weekRangeTitle)
                    .font(MossTypography.editorial(18, weight: .semibold))
                    .monospacedDigit()
                Label("左右拖动这段时间链，浏览整周排程", systemImage: "hand.draw")
                    .font(MossTypography.font(9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .offset(x: weekDragOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        weekDragOffset = max(-70, min(70, value.translation.width * 0.32))
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 42
                        if value.translation.width > threshold {
                            moveWeek(by: -1)
                        } else if value.translation.width < -threshold {
                            moveWeek(by: 1)
                        }
                        weekDragOffset = 0
                    }
            )

            Button {
                moveWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
            .help("下一周")

            Button("本周") {
                weekStart = Self.startOfWeek(containing: .now)
            }
            .buttonStyle(CapsuleButtonStyle())

            Spacer()

            ScheduleMetric(
                value: "\(weekPlans.count)",
                label: "全部计划",
                color: MossTheme.sage
            )
            ScheduleMetric(
                value: Self.minutesLabel(plannedMinutes),
                label: "待投入",
                color: MossTheme.apricot
            )
            ScheduleMetric(
                value: "\(waitingPlans.count)",
                label: "待排时间",
                color: MossTheme.mint
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    MossTheme.card.opacity(0.72),
                    MossTheme.sage.opacity(0.045),
                    MossTheme.card.opacity(0.56)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.15),
            value: weekDragOffset
        )
    }

    private var waitingStrip: some View {
        HStack(spacing: 10) {
            Label("待排入时间链", systemImage: "tray.full")
                .font(MossTypography.font(9, weight: .bold))
                .foregroundStyle(MossTheme.apricot)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(waitingPlans) { plan in
                        Button {
                            onEdit(plan)
                        } label: {
                            HStack(spacing: 6) {
                                Text(plan.scheduledAt.formatted(.dateTime.weekday(.abbreviated)))
                                    .foregroundStyle(MossTheme.sage)
                                Text(plan.title)
                                    .lineLimit(1)
                                Text("· \(Self.minutesLabel(plan.estimatedMinutes))")
                                    .foregroundStyle(.secondary)
                            }
                            .font(MossTypography.font(9, weight: .semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                MossTheme.apricot.opacity(0.07),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().stroke(MossTheme.apricot.opacity(0.18))
                            )
                        }
                        .buttonStyle(MossJellyPlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(MossTheme.apricot.opacity(0.025))
    }

    private var hourGutter: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(width: hourGutterWidth, height: ScheduleDayColumn.headerHeight)

            ZStack(alignment: .topTrailing) {
                Color.clear

                ForEach(startHour...endHour, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour))
                        .font(MossTypography.font(8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .offset(y: CGFloat(hour - startHour) * hourHeight - 6)
                }
            }
            .frame(
                width: hourGutterWidth,
                height: CGFloat(endHour - startHour) * hourHeight
            )
            .padding(.trailing, 8)
        }
    }

    private var weekRangeTitle: String {
        guard let lastDay = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return weekStart.formatted(.dateTime.year().month().day())
        }
        if calendar.component(.month, from: weekStart)
            == calendar.component(.month, from: lastDay) {
            return "\(weekStart.formatted(.dateTime.year().month(.wide))) · \(calendar.component(.day, from: weekStart))—\(calendar.component(.day, from: lastDay))"
        }
        return "\(weekStart.formatted(.dateTime.month().day())) — \(lastDay.formatted(.dateTime.month().day()))"
    }

    private func isPlacedOnTimeline(_ plan: PlanEntry) -> Bool {
        let minute = minuteOfDay(plan.scheduledAt)
        return minute >= startHour * 60 && minute < endHour * 60
    }

    private func minuteOfDay(_ date: Date) -> Int {
        calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
    }

    private func createPlan(on day: Date, startMinute: Int, duration: Int) {
        let dayStart = calendar.startOfDay(for: day)
        let date = calendar.date(
            byAdding: .minute,
            value: startMinute,
            to: dayStart
        ) ?? day
        onCreate(date, duration)
    }

    private func movePlan(_ plan: PlanEntry, _ dayShift: Int, _ minuteShift: Int) {
        let duration = max(15, plan.estimatedMinutes)
        let currentMinute = minuteOfDay(plan.scheduledAt)
        let targetMinute = min(
            endHour * 60 - duration,
            max(startHour * 60, currentMinute + minuteShift)
        )
        let currentDay = calendar.startOfDay(for: plan.scheduledAt)
        let destinationDay = calendar.date(
            byAdding: .day,
            value: dayShift,
            to: currentDay
        ) ?? currentDay
        guard let destination = calendar.date(
            byAdding: .minute,
            value: targetMinute,
            to: destinationDay
        ) else { return }

        var updated = plan
        updated.scheduledAt = destination
        dataStore.updatePlan(updated)
    }

    private func moveWeek(by offset: Int) {
        guard let moved = calendar.date(
            byAdding: .day,
            value: offset * 7,
            to: weekStart
        ) else { return }
        if reduceMotion {
            weekStart = moved
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                weekStart = moved
            }
        }
    }

    private static func startOfWeek(containing date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    fileprivate static func minutesLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }
}

private struct ScheduleMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MossTypography.font(12, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(MossTypography.font(8, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.075), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.13)))
    }
}

private struct ScheduleDayColumn: View {
    static let headerHeight: CGFloat = 76

    let day: Date
    let plans: [PlanEntry]
    let allDayLoadMinutes: Int
    let width: CGFloat
    let hourHeight: CGFloat
    let startHour: Int
    let endHour: Int
    let onSelectRange: (Int, Int) -> Void
    let onMove: (PlanEntry, Int, Int) -> Void
    let onEdit: (PlanEntry) -> Void

    @State private var selectionAnchor: Int?
    @State private var selectionCurrent: Int?

    private var calendar: Calendar { Calendar.current }

    private var timelineHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }

    var body: some View {
        VStack(spacing: 0) {
            dayHeader

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(isToday ? MossTheme.sage.opacity(0.025) : Color.clear)
                    .contentShape(Rectangle())
                    .gesture(selectionGesture)

                timelineGrid

                if let selectionRange {
                    selectionBlock(selectionRange)
                }

                if isToday && nowIsVisible {
                    nowLine
                }

                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    SchedulePlanBlock(
                        plan: plan,
                        width: width - 9,
                        height: blockHeight(for: plan),
                        hourHeight: hourHeight,
                        dayWidth: width,
                        onMove: onMove,
                        onEdit: onEdit
                    )
                    .offset(
                        x: 4,
                        y: blockOffset(for: plan) + CGFloat(index % 3) * 1.5
                    )
                    .zIndex(plan.status == .planned ? 3 : 1)
                }
            }
            .frame(width: width, height: timelineHeight)
        }
        .frame(width: width)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MossTheme.hairline.opacity(0.72))
                .frame(width: 1)
        }
    }

    private var dayHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated)))
                        .font(MossTypography.font(8, weight: .bold))
                        .foregroundStyle(isToday ? MossTheme.sage : .secondary)
                    Text(String(calendar.component(.day, from: day)))
                        .font(MossTypography.editorial(19, weight: .semibold))
                        .foregroundStyle(isToday ? MossTheme.sage : .primary)
                }
                Spacer(minLength: 2)
                Text(PlanScheduleBoard.minutesLabel(allDayLoadMinutes))
                    .font(MossTypography.font(8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                let fraction = min(1, CGFloat(allDayLoadMinutes) / 480)
                ZStack(alignment: .leading) {
                    Capsule().fill(MossTheme.quietFill)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MossTheme.sage, MossTheme.apricot],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .frame(width: width, height: Self.headerHeight)
        .background(
            isToday
                ? MossTheme.sage.opacity(0.075)
                : MossTheme.card.opacity(0.42)
        )
    }

    private var timelineGrid: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...(endHour - startHour), id: \.self) { offset in
                Rectangle()
                    .fill(
                        offset == 0
                            ? MossTheme.hairline
                            : MossTheme.hairline.opacity(0.68)
                    )
                    .frame(width: width, height: 1)
                    .offset(y: CGFloat(offset) * hourHeight)
            }

            ForEach(0..<(endHour - startHour), id: \.self) { offset in
                Rectangle()
                    .fill(MossTheme.hairline.opacity(0.28))
                    .frame(width: width, height: 1)
                    .offset(y: CGFloat(offset) * hourHeight + hourHeight / 2)
            }
        }
        .allowsHitTesting(false)
    }

    private var nowLine: some View {
        let nowMinute = minuteOfDay(.now)
        let y = CGFloat(nowMinute - startHour * 60) / 60 * hourHeight
        return HStack(spacing: 0) {
            Circle()
                .fill(MossTheme.apricot)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(MossTheme.apricot.opacity(0.72))
                .frame(height: 1)
        }
        .offset(x: -3, y: y)
        .allowsHitTesting(false)
    }

    private var nowIsVisible: Bool {
        let minute = minuteOfDay(.now)
        return minute >= startHour * 60 && minute <= endHour * 60
    }

    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                let minute = minute(at: value.location.y)
                if selectionAnchor == nil {
                    selectionAnchor = minute
                }
                selectionCurrent = minute
            }
            .onEnded { value in
                guard let anchor = selectionAnchor else { return }
                let current = minute(at: value.location.y)
                let lower = min(anchor, current)
                let upper = max(anchor, current)
                let duration = max(15, upper == lower ? 30 : upper - lower)
                let safeDuration = min(duration, endHour * 60 - lower)
                selectionAnchor = nil
                selectionCurrent = nil
                onSelectRange(lower, safeDuration)
            }
    }

    private var selectionRange: (start: Int, duration: Int)? {
        guard let anchor = selectionAnchor, let current = selectionCurrent else {
            return nil
        }
        let lower = min(anchor, current)
        let upper = max(anchor, current)
        return (lower, max(15, upper == lower ? 30 : upper - lower))
    }

    private func selectionBlock(
        _ range: (start: Int, duration: Int)
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeLabel(range.start))
                .font(MossTypography.font(9, weight: .bold))
                .monospacedDigit()
            Text("\(range.duration) 分钟")
                .font(MossTypography.font(8, weight: .medium))
        }
        .foregroundStyle(MossTheme.sage)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(
            width: width - 8,
            height: max(28, CGFloat(range.duration) / 60 * hourHeight - 3),
            alignment: .topLeading
        )
        .background(
            MossTheme.sage.opacity(0.13),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    MossTheme.sage.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
        .offset(
            x: 4,
            y: CGFloat(range.start - startHour * 60) / 60 * hourHeight
        )
        .allowsHitTesting(false)
        .zIndex(5)
    }

    private func minute(at y: CGFloat) -> Int {
        let raw = startHour * 60 + Int((max(0, min(timelineHeight, y)) / hourHeight) * 60)
        let rounded = Int((Double(raw) / 15).rounded()) * 15
        return min(endHour * 60 - 15, max(startHour * 60, rounded))
    }

    private func blockOffset(for plan: PlanEntry) -> CGFloat {
        CGFloat(minuteOfDay(plan.scheduledAt) - startHour * 60) / 60 * hourHeight
    }

    private func blockHeight(for plan: PlanEntry) -> CGFloat {
        let remainingMinutes = max(
            15,
            endHour * 60 - minuteOfDay(plan.scheduledAt)
        )
        let visibleMinutes = min(max(15, plan.estimatedMinutes), remainingMinutes)
        return max(28, CGFloat(visibleMinutes) / 60 * hourHeight - 4)
    }

    private func minuteOfDay(_ date: Date) -> Int {
        calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
    }

    private func timeLabel(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}

private struct SchedulePlanBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let plan: PlanEntry
    let width: CGFloat
    let height: CGFloat
    let hourHeight: CGFloat
    let dayWidth: CGFloat
    let onMove: (PlanEntry, Int, Int) -> Void
    let onEdit: (PlanEntry) -> Void

    @State private var translation: CGSize = .zero
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(plan.scheduledAt.formatted(.dateTime.hour().minute()))
                    .font(MossTypography.font(8, weight: .bold))
                    .monospacedDigit()
                Spacer(minLength: 0)
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
            }

            Text(plan.title)
                .font(MossTypography.font(9, weight: .semibold))
                .lineLimit(height > 48 ? 2 : 1)

            if height > 58 {
                Text(PlanScheduleBoard.minutesLabel(plan.estimatedMinutes))
                    .font(MossTypography.font(8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    blockColor.opacity(plan.status == .completed ? 0.13 : 0.19),
                    MossTheme.card.opacity(0.93)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(blockColor.opacity(isHovered ? 0.58 : 0.30))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(blockColor)
                .frame(width: 3)
                .padding(.vertical, 5)
        }
        .shadow(
            color: Color.black.opacity(isHovered ? 0.10 : 0.035),
            radius: isHovered ? 9 : 3,
            y: isHovered ? 5 : 1
        )
        .opacity(plan.status == .skipped ? 0.55 : 1)
        .offset(translation)
        .scaleEffect(isHovered && !reduceMotion ? 1.012 : 1)
        .onHover { isHovered = $0 }
        .onTapGesture {
            onEdit(plan)
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    translation = value.translation
                }
                .onEnded { value in
                    let dayShift = Int((value.translation.width / dayWidth).rounded())
                    let rawMinuteShift = value.translation.height / hourHeight * 60
                    let minuteShift = Int((rawMinuteShift / 15).rounded()) * 15
                    translation = .zero
                    if dayShift != 0 || minuteShift != 0 {
                        onMove(plan, dayShift, minuteShift)
                    }
                }
        )
        .help("拖动以改期；点击编辑")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(plan.title)，\(plan.scheduledAt.formatted(.dateTime.weekday().hour().minute()))，\(plan.estimatedMinutes) 分钟"
        )
        .mossPlanContextMenu(plan: plan, onEdit: { onEdit(plan) })
    }

    private var blockColor: Color {
        switch plan.status {
        case .planned: MossTheme.sage
        case .completed: MossTheme.mint
        case .skipped: Color.secondary
        }
    }

    private var statusColor: Color {
        switch plan.status {
        case .planned: MossTheme.apricot
        case .completed: MossTheme.mint
        case .skipped: Color.secondary
        }
    }
}

extension View {
    func mossPlanContextMenu(
        plan: PlanEntry,
        onEdit: @escaping () -> Void
    ) -> some View {
        modifier(PlanContextMenuModifier(plan: plan, onEdit: onEdit))
    }
}

private struct PlanContextMenuModifier: ViewModifier {
    @EnvironmentObject private var dataStore: DataStore

    let plan: PlanEntry
    let onEdit: () -> Void

    @State private var isConfirmingDelete = false

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    onEdit()
                } label: {
                    Label("编辑计划", systemImage: "pencil")
                }

                Button {
                    duplicateIntoNextSlot()
                } label: {
                    Label("复制到下一时段", systemImage: "plus.square.on.square")
                }

                Divider()

                if plan.status == .completed {
                    Button {
                        dataStore.setPlanStatus(id: plan.id, status: .planned)
                    } label: {
                        Label("恢复为待开始", systemImage: "arrow.uturn.backward.circle")
                    }
                } else {
                    Button {
                        dataStore.setPlanStatus(id: plan.id, status: .completed)
                    } label: {
                        Label("标记完成", systemImage: "checkmark.circle")
                    }
                }

                if plan.status != .skipped {
                    Button {
                        dataStore.setPlanStatus(id: plan.id, status: .skipped)
                    } label: {
                        Label("暂时搁置", systemImage: "pause.circle")
                    }
                }

                Divider()

                Button {
                    move(toDayOffset: 0)
                } label: {
                    Label("移到今天", systemImage: "sun.max")
                }
                .disabled(Calendar.current.isDateInToday(plan.scheduledAt))

                Button {
                    move(toDayOffset: 1)
                } label: {
                    Label("移到明天", systemImage: "calendar.badge.plus")
                }
                .disabled(Calendar.current.isDateInTomorrow(plan.scheduledAt))

                Divider()

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("删除计划…", systemImage: "trash")
                }
            }
            .confirmationDialog(
                "删除「\(plan.title)」？",
                isPresented: $isConfirmingDelete
            ) {
                Button("删除计划", role: .destructive) {
                    dataStore.deletePlan(id: plan.id)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只删除这条计划，不会删除关联任务或已经完成的专注记录。")
            }
    }

    private func duplicateIntoNextSlot() {
        let calendar = Calendar.current
        var copy = plan
        copy.id = UUID()
        copy.title = "\(plan.title)（副本）"
        copy.scheduledAt = calendar.date(
            byAdding: .minute,
            value: max(15, plan.estimatedMinutes),
            to: plan.scheduledAt
        ) ?? plan.scheduledAt
        copy.linkedTaskID = nil
        copy.statusRaw = PlanStatus.planned.rawValue
        copy.createdAt = .now
        copy.updatedAt = .now
        copy.completedAt = nil
        dataStore.addPlan(copy)
    }

    private func move(toDayOffset offset: Int) {
        let calendar = Calendar.current
        let destinationDay = calendar.date(
            byAdding: .day,
            value: offset,
            to: calendar.startOfDay(for: .now)
        ) ?? .now
        let time = calendar.dateComponents(
            [.hour, .minute, .second],
            from: plan.scheduledAt
        )
        guard let destination = calendar.date(
            bySettingHour: time.hour ?? 9,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: destinationDay
        ) else { return }

        var updated = plan
        updated.scheduledAt = destination
        dataStore.updatePlan(updated)
    }
}
