import SwiftUI

struct TimelineRangePicker: View {
    @Binding var selection: TimelineRange

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredItem: TimelineRange?
    @Namespace private var selectionMotion

    var body: some View {
        HStack(spacing: 11) {
            Text("时间范围")
                .font(MossTypography.font(11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                ForEach(TimelineRange.allCases) { item in
                    let isSelected = selection == item
                    let isHovered = hoveredItem == item

                    Button {
                        withAnimation(
                            reduceMotion
                                ? .linear(duration: 0.01)
                                : .spring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.04)
                        ) {
                            selection = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(MossTypography.font(12, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? MossTheme.mint
                                    : Color.primary.opacity(isHovered ? 0.88 : 0.62)
                            )
                            .frame(width: 43, height: 30)
                            .background {
                                ZStack {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(MossTheme.sage.opacity(0.18))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                    .stroke(MossTheme.mint.opacity(0.34), lineWidth: 1)
                                            }
                                            .matchedGeometryEffect(
                                                id: "timeline-range-selection",
                                                in: selectionMotion
                                            )
                                    } else if isHovered {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(Color.primary.opacity(0.065))
                                    }
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.95))
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            if hovering {
                                hoveredItem = item
                            } else if hoveredItem == item {
                                hoveredItem = nil
                            }
                        }
                    }
                    .accessibilityLabel(item.rawValue)
                    .accessibilityValue(isSelected ? "已选择" : "未选择")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(3)
            .background(
                Color.primary.opacity(0.032),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MossTheme.hairline.opacity(0.78), lineWidth: 1)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("时间范围")
    }
}

struct TimelineFilterMenu<Content: View>: View {
    let title: String
    let accessibilityLabel: String
    let isActive: Bool
    let width: CGFloat
    private let content: Content

    @State private var isHovered = false

    init(
        title: String,
        accessibilityLabel: String,
        isActive: Bool,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.isActive = isActive
        self.width = width
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                TimelineDownChevron()
                    .foregroundStyle(isActive ? MossTheme.sage : .secondary)
            }
            .font(MossTypography.font(12, weight: .semibold))
            .foregroundStyle(isActive ? MossTheme.sage : Color.primary.opacity(0.84))
            .padding(.horizontal, 11)
            .frame(width: width, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .mossJellyHover(scale: 1.035, lift: 2, glow: 0.12)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        if isActive {
            return MossTheme.sage.opacity(isHovered ? 0.16 : 0.11)
        }
        return Color.primary.opacity(isHovered ? 0.075 : 0.045)
    }

    private var borderColor: Color {
        isActive ? MossTheme.sage.opacity(0.28) : MossTheme.hairline.opacity(isHovered ? 1.3 : 0.8)
    }
}

private struct TimelineDownChevron: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0.5, y: 0.75))
            path.addLine(to: CGPoint(x: 4, y: 4.25))
            path.addLine(to: CGPoint(x: 7.5, y: 0.75))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
        .frame(width: 8, height: 5)
    }
}

struct TimelineDateSelector: View {
    @Binding var selection: Date

    @State private var isPresented = false
    @State private var isHovered = false
    @State private var displayedMonth = Date.now

    var body: some View {
        Button {
            displayedMonth = Calendar.current.date(
                from: Calendar.current.dateComponents([.year, .month], from: selection)
            ) ?? selection
            isPresented.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MossTheme.sage)
                Text(selection, format: .dateTime.year().month().day())
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(MossTypography.font(12, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.86))
            .padding(.horizontal, 11)
            .frame(height: 34)
        }
        .buttonStyle(TimelineDateButtonStyle(isHovered: isHovered, isPresented: isPresented))
        .mossJellyHover(scale: 1.035, lift: 2, glow: 0.12)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            TimelineCalendarPopover(
                selection: $selection,
                displayedMonth: $displayedMonth
            ) {
                withAnimation(.easeOut(duration: 0.14)) {
                    isPresented = false
                }
            }
            .presentationBackground(.clear)
        }
        .help("选择日期")
        .accessibilityLabel("选择日期，当前为 \(selection.formatted(.dateTime.year().month().day()))")
    }
}

private struct TimelineCalendarPopover: View {
    @Binding var selection: Date
    @Binding var displayedMonth: Date
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredDate: Date?

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale.current
        return calendar
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -leadingDays,
            to: monthInterval.start
        ) else {
            return []
        }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            dayGrid
        }
        .padding(14)
        .frame(width: 304)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(MossTheme.card)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MossTheme.sage.opacity(0.20), lineWidth: 1)
        }
        .padding(3)
        .mossTypography()
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(displayedMonth, format: .dateTime.year().month(.wide))
                    .font(MossTypography.font(15, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.92))
                Text(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month) ? "本月" : "选择日期")
                    .font(MossTypography.font(9, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("今天") {
                selection = .now
                displayedMonth = monthStart(for: .now)
                onSelect()
            }
            .font(MossTypography.font(9, weight: .semibold))
            .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.93))
            .foregroundStyle(MossTheme.sage)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(MossTheme.sage.opacity(0.11), in: Capsule())

            calendarNavigationButton("chevron.left", label: "上个月") {
                moveMonth(by: -1)
            }
            calendarNavigationButton("chevron.right", label: "下个月") {
                moveMonth(by: 1)
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 0
        ) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(MossTypography.font(9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.72))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 1)
    }

    private var dayGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 5
        ) {
            ForEach(monthDates, id: \.self) { date in
                dayButton(date)
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)
        let isInDisplayedMonth = calendar.isDate(
            date,
            equalTo: displayedMonth,
            toGranularity: .month
        )
        let isHovered = hoveredDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        return Button {
            selection = date
            onSelect()
        } label: {
            Text(date, format: .dateTime.day())
                .font(MossTypography.font(10, weight: isSelected ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(dayForeground(
                    isSelected: isSelected,
                    isInDisplayedMonth: isInDisplayedMonth
                ))
                .frame(width: 31, height: 29)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(dayBackground(isSelected: isSelected, isHovered: isHovered))
                }
                .overlay {
                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(MossTheme.sage.opacity(0.42), lineWidth: 1)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.10)) {
                if hovering {
                    hoveredDate = date
                } else if hoveredDate.map({ calendar.isDate($0, inSameDayAs: date) }) == true {
                    hoveredDate = nil
                }
            }
        }
        .accessibilityLabel(date.formatted(.dateTime.year().month().day().weekday(.wide)))
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func calendarNavigationButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.66))
                .frame(width: 27, height: 27)
                .background(Color.primary.opacity(0.045), in: Circle())
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.88))
        .mossJellyHover(scale: 1.08, lift: 1, glow: 0.10)
        .accessibilityLabel(label)
    }

    private func moveMonth(by amount: Int) {
        let change = {
            displayedMonth = calendar.date(
                byAdding: .month,
                value: amount,
                to: displayedMonth
            ) ?? displayedMonth
        }
        if reduceMotion {
            change()
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                change()
            }
        }
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
    }

    private func dayForeground(
        isSelected: Bool,
        isInDisplayedMonth: Bool
    ) -> Color {
        if isSelected { return MossTheme.current.accentForeground }
        return Color.primary.opacity(isInDisplayedMonth ? 0.86 : 0.26)
    }

    private func dayBackground(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected { return MossTheme.sage }
        if isHovered { return MossTheme.sage.opacity(0.13) }
        return .clear
    }
}

struct TimelineNavigationButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(TimelineNavigationButtonStyle(isHovered: isHovered))
        .mossJellyHover(scale: 1.10, lift: 2, glow: 0.14)
        .onHover { isHovered = $0 }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct TimelineDateButtonStyle: ButtonStyle {
    let isHovered: Bool
    let isPresented: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isPresented ? MossTheme.sage.opacity(0.32) : MossTheme.hairline.opacity(isHovered ? 1.3 : 0.8),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.955 : 1)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.52, blendDuration: 0.06),
                value: configuration.isPressed
            )
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPresented {
            return MossTheme.sage.opacity(0.12)
        }
        return Color.primary.opacity(isPressed ? 0.10 : (isHovered ? 0.075 : 0.045))
    }
}

private struct TimelineNavigationButtonStyle: ButtonStyle {
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered ? MossTheme.sage : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? MossTheme.sage.opacity(0.16)
                            : Color.primary.opacity(isHovered ? 0.075 : 0.035)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isHovered ? MossTheme.sage.opacity(0.22) : MossTheme.hairline.opacity(0.7),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(
                .spring(response: 0.22, dampingFraction: 0.50, blendDuration: 0.06),
                value: configuration.isPressed
            )
    }
}
