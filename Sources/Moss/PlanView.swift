import SwiftUI
import UniformTypeIdentifiers

private enum PlanShelf: String, CaseIterable, Identifiable {
    case schedule = "排程"
    case today = "今天"
    case upcoming = "未来"
    case journal = "手记"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .schedule: "rectangle.3.group.fill"
        case .today: "sun.max.fill"
        case .upcoming: "calendar"
        case .journal: "book.pages.fill"
        }
    }
}

private struct PlanEditorDraft: Identifiable {
    let id = UUID()
    let scheduledAt: Date
    let estimatedMinutes: Int
}

struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore

    let journalComposerRequest: UUID?
    let onJournalComposerRequestHandled: (UUID) -> Void

    @State private var shelf: PlanShelf = .schedule
    @State private var selectedPlanID: UUID?
    @State private var selectedRecordID: UUID?
    @State private var editingPlan: PlanEntry?
    @State private var newPlanDraft: PlanEditorDraft?
    @State private var isImportingJournal = false
    @State private var isWritingJournal = false
    @State private var editingJournalRecord: JournalRecord?
    @State private var importFeedback: String?
    @State private var hasPreloadedShelves = false

    init(
        journalComposerRequest: UUID? = nil,
        onJournalComposerRequestHandled: @escaping (UUID) -> Void = { _ in }
    ) {
        self.journalComposerRequest = journalComposerRequest
        self.onJournalComposerRequestHandled = onJournalComposerRequestHandled
    }

    private var visiblePlans: [PlanEntry] {
        plans(for: shelf)
    }

    private func plans(for targetShelf: PlanShelf) -> [PlanEntry] {
        let calendar = Calendar.current
        switch targetShelf {
        case .schedule:
            return []
        case .today:
            return dataStore.plans.filter {
                calendar.isDateInToday($0.scheduledAt)
                    || ($0.status == .planned && $0.scheduledAt < Date.now.dayStart)
            }
        case .upcoming:
            return dataStore.plans.filter {
                $0.scheduledAt >= Date.now.dayStart.addingTimeInterval(86_400)
                    || $0.status == .skipped
            }
        case .journal:
            return []
        }
    }

    private var selectedPlan: PlanEntry? {
        visiblePlans.first { $0.id == selectedPlanID }
    }

    private var selectedRecord: JournalRecord? {
        dataStore.journalRecords.first { $0.id == selectedRecordID }
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader

            Divider().opacity(0.55)

            shelfSwitcher

            Divider().opacity(0.55)

            if shelf == .schedule {
                PlanScheduleBoard(
                    onCreate: presentPlanEditor,
                    onEdit: { editingPlan = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    planShelf
                        .frame(width: 286)

                    Divider().opacity(0.55)

                    detailPage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    MossTheme.paper,
                    MossTheme.sage.opacity(0.035),
                    MossTheme.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(item: $newPlanDraft) { draft in
            PlanEditorView(
                initialScheduledAt: draft.scheduledAt,
                initialEstimatedMinutes: draft.estimatedMinutes
            )
            .id(draft.id)
        }
        .sheet(item: $editingPlan) { plan in
            PlanEditorView(plan: plan)
        }
        .sheet(isPresented: $isWritingJournal) {
            JournalEditorView { record in
                selectedRecordID = record.id
                selectShelf(.journal)
            }
        }
        .sheet(item: $editingJournalRecord) { record in
            JournalEditorView(record: record) { savedRecord in
                selectedRecordID = savedRecord.id
                selectShelf(.journal)
            }
        }
        .fileImporter(
            isPresented: $isImportingJournal,
            allowedContentTypes: [.folder, .html, .pdf, .plainText],
            allowsMultipleSelection: true,
            onCompletion: importJournal
        )
        .alert(
            "手记导入",
            isPresented: Binding(
                get: { importFeedback != nil },
                set: { if !$0 { importFeedback = nil } }
            )
        ) {
            Button("知道了") { importFeedback = nil }
        } message: {
            Text(importFeedback ?? "")
        }
        .onAppear {
            prepareInitialSelections()
            handleJournalComposerRequest(journalComposerRequest)
        }
        .task {
            guard !hasPreloadedShelves else { return }
            await Task.yield()
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                hasPreloadedShelves = true
            }
        }
        .onChange(of: dataStore.plans.map(\.id)) { _, _ in alignSelection() }
        .onChange(of: dataStore.journalRecords.map(\.id)) { _, _ in alignSelection() }
        .onChange(of: journalComposerRequest) { _, request in
            handleJournalComposerRequest(request)
        }
    }

    private var pageHeader: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PLAN & JOURNAL")
                    .font(MossTypography.font(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(MossTheme.sage)
                Text(shelf == .schedule ? "计划排程" : shelf == .journal ? "手记" : "计划")
                    .font(MossTypography.editorial(29, weight: .semibold))
                Text(
                    shelf == .schedule
                        ? "拖出时间，编排一周，让计划成为看得见的节奏。"
                        : "把未来写成一页，再从一件小事开始。"
                )
                    .font(MossTypography.font(12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if shelf == .journal {
                Button {
                    isImportingJournal = true
                } label: {
                    Label("导入 Apple 手记", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(CapsuleButtonStyle())
                .help("选择 Apple 手记导出文件夹、index.html、PDF 或文本")
            } else {
                Button {
                    presentPlanEditor(nextAvailablePlanStart(), 25)
                } label: {
                    Label("写下计划", systemImage: "plus")
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
            }

            Button {
                openJournalComposer()
            } label: {
                Label("写手记", systemImage: "square.and.pencil")
            }
            .buttonStyle(
                CapsuleButtonStyle(prominent: shelf == .journal)
            )
            .help("无需先选择记录，直接开始写")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var shelfSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(PlanShelf.allCases) { item in
                Button {
                    selectShelf(item)
                } label: {
                    Label(item.rawValue, systemImage: item.symbol)
                        .font(MossTypography.font(10, weight: .semibold))
                        .foregroundStyle(shelf == item ? MossTheme.sage : .secondary)
                        .frame(minWidth: 64)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            shelf == item ? MossTheme.sage.opacity(0.11) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                }
                .buttonStyle(PlanShelfTabButtonStyle())
            }

            Spacer()

            if shelf == .schedule {
                Label("在空白时间上拖动即可新建", systemImage: "cursorarrow.motionlines")
                    .font(MossTypography.font(9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(MossTheme.quietFill.opacity(0.55))
    }

    private var planShelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(shelf == .journal ? "我的记录" : shelf == .today ? "今天这一页" : "接下来的日子")
                .font(MossTypography.font(11, weight: .bold))
                .foregroundStyle(.secondary)

            ZStack {
                planShelfScroll(for: .today)
                    .shelfLayer(isActive: shelf == .today)

                if hasPreloadedShelves || shelf == .upcoming {
                    planShelfScroll(for: .upcoming)
                        .shelfLayer(isActive: shelf == .upcoming)
                }

                if hasPreloadedShelves || shelf == .journal {
                    journalShelfScroll
                        .shelfLayer(isActive: shelf == .journal)
                }
            }
            .frame(maxHeight: .infinity)

            if shelf == .journal {
                journalImportHint
            }
        }
        .padding(18)
        .background(.ultraThinMaterial.opacity(0.62))
    }

    @ViewBuilder
    private func planRows(for targetShelf: PlanShelf) -> some View {
        let targetPlans = plans(for: targetShelf)
        if targetPlans.isEmpty {
            PlanShelfEmpty(
                symbol: targetShelf == .today ? "sun.haze" : "calendar.badge.plus",
                title: targetShelf == .today ? "今天还没有安排" : "未来留有余地",
                subtitle: "写下一件值得专注的小事。"
            )
        } else {
            ForEach(targetPlans) { plan in
                Button {
                    selectedPlanID = plan.id
                } label: {
                    PlanShelfRow(
                        plan: plan,
                        isSelected: selectedPlanID == plan.id
                    )
                }
                .buttonStyle(MossJellyPlainButtonStyle())
                .mossPlanContextMenu(
                    plan: plan,
                    onEdit: { editingPlan = plan }
                )
            }
        }
    }

    private func planShelfScroll(for targetShelf: PlanShelf) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                planRows(for: targetShelf)
            }
            .padding(.vertical, 2)
        }
    }

    private var journalShelfScroll: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                journalRows
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var journalRows: some View {
        if dataStore.journalRecords.isEmpty {
            PlanShelfEmpty(
                symbol: "book.closed",
                title: "这里还没有手记",
                subtitle: "可选择 Apple 手记导出文件夹或 index.html。"
            )
        } else {
            ForEach(dataStore.journalRecordSummaries) { summary in
                Button {
                    selectedRecordID = summary.id
                } label: {
                    JournalShelfRow(
                        summary: summary,
                        isSelected: selectedRecordID == summary.id
                    )
                }
                .buttonStyle(MossJellyPlainButtonStyle())
            }
        }
    }

    private var journalImportHint: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("隐私边界", systemImage: "lock.shield")
                .font(MossTypography.font(10, weight: .bold))
                .foregroundStyle(MossTheme.sage)
            Text("Moss 不会读取受保护的手记数据库；只有你主动选择的导出文件会保存在本机。")
                .font(MossTypography.font(9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(MossTheme.sage.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
    }

    @ViewBuilder
    private var detailPage: some View {
        ZStack {
            if shelf != .journal {
                planDetailPage
            }

            if hasPreloadedShelves || shelf == .journal {
                journalDetailPage
                    .shelfLayer(isActive: shelf == .journal)
            }
        }
    }

    @ViewBuilder
    private var planDetailPage: some View {
        if let selectedPlan {
            PlanEntryPage(
                plan: selectedPlan,
                onEdit: { editingPlan = selectedPlan }
            )
        } else {
            PlanDayPage()
        }
    }

    @ViewBuilder
    private var journalDetailPage: some View {
        if let selectedRecord {
            JournalRecordPage(
                record: selectedRecord,
                onEdit: selectedRecord.source == .moss
                    ? { editingJournalRecord = selectedRecord }
                    : nil
            )
        } else {
            PlanJournalOverview(onWrite: openJournalComposer)
        }
    }

    private func alignSelection() {
        if shelf == .journal {
            if selectedRecord == nil {
                selectedRecordID = dataStore.journalRecords.first?.id
            }
            return
        }
        if selectedPlan == nil {
            selectedPlanID = visiblePlans.first?.id
        }
    }

    private func prepareInitialSelections() {
        alignSelection()
        if selectedRecordID == nil {
            selectedRecordID = dataStore.journalRecords.first?.id
        }
    }

    private func selectShelf(_ newShelf: PlanShelf) {
        guard shelf != newShelf else { return }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            if newShelf == .journal, selectedRecordID == nil {
                selectedRecordID = dataStore.journalRecords.first?.id
            }
            shelf = newShelf
        }
    }

    private func openJournalComposer() {
        selectShelf(.journal)
        isWritingJournal = true
    }

    private func presentPlanEditor(_ start: Date, _ minutes: Int) {
        newPlanDraft = PlanEditorDraft(
            scheduledAt: start,
            estimatedMinutes: max(15, min(240, minutes))
        )
    }

    private func nextAvailablePlanStart() -> Date {
        let calendar = Calendar.current
        let now = Date.now
        let minute = calendar.component(.minute, from: now)
        let roundedForward = (15 - minute % 15) % 15
        var candidate = calendar.date(
            byAdding: .minute,
            value: roundedForward,
            to: now
        ) ?? now

        let hour = calendar.component(.hour, from: candidate)
        if hour < 6 {
            candidate = calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: candidate
            ) ?? candidate
        } else if hour >= 22 {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            candidate = calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: tomorrow
            ) ?? tomorrow
        }
        return candidate
    }

    private func handleJournalComposerRequest(_ request: UUID?) {
        guard let request else { return }
        openJournalComposer()
        onJournalComposerRequestHandled(request)
    }

    private func importJournal(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            var parsedRecords: [JournalRecord] = []
            var failures: [String] = []
            for url in urls {
                do {
                    parsedRecords.append(contentsOf: try JournalImportService.records(from: url))
                } catch {
                    failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
            let imported = dataStore.addJournalRecords(parsedRecords)
            let duplicates = max(0, parsedRecords.count - imported)
            shelf = .journal
            selectedRecordID = dataStore.journalRecords.first?.id
            if failures.isEmpty {
                importFeedback = duplicates > 0
                    ? "已新增 \(imported) 篇，跳过 \(duplicates) 篇重复记录。内容只保存在 Moss 本机。"
                    : "已导入 \(imported) 篇记录，内容只保存在 Moss 本机数据中。"
            } else {
                importFeedback = "已导入 \(imported) 份；\(failures.joined(separator: "\n"))"
            }
        } catch {
            importFeedback = "没有导入：\(error.localizedDescription)"
        }
    }
}

private struct PlanShelfRow: View {
    let plan: PlanEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            VStack(spacing: 2) {
                Text(plan.scheduledAt.formatted(.dateTime.day()))
                    .font(MossTypography.editorial(19, weight: .semibold))
                Text(plan.scheduledAt.formatted(.dateTime.month(.abbreviated)))
                    .font(MossTypography.font(8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(MossTypography.font(12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5, height: 5)
                    Text(plan.status.title)
                    Text("·")
                    Text("\(plan.estimatedMinutes) 分钟")
                }
                .font(MossTypography.font(9, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(11)
        .background(
            isSelected ? MossTheme.sage.opacity(0.115) : MossTheme.quietFill,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? MossTheme.sage.opacity(0.36) : MossTheme.hairline)
        }
        .mossJellyHover(scale: 1.018, lift: 1, glow: 0.07)
    }

    private var statusColor: Color {
        switch plan.status {
        case .planned: MossTheme.apricot
        case .completed: MossTheme.mint
        case .skipped: .secondary
        }
    }
}

private struct JournalShelfRow: View {
    let summary: JournalRecordSummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(summary.entryDate.formatted(.dateTime.month().day()))
                    .font(MossTypography.font(9, weight: .bold))
                    .foregroundStyle(MossTheme.sage)
                Spacer()
                Image(systemName: summary.source == .appleJournal ? "apple.logo" : "leaf.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(summary.title)
                .font(MossTypography.editorial(14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(summary.preview)
                .font(MossTypography.font(9))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            isSelected ? MossTheme.sage.opacity(0.115) : MossTheme.quietFill,
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? MossTheme.sage.opacity(0.36) : MossTheme.hairline)
        }
    }
}

private struct PlanShelfTabButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? 0.035 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.08),
                value: configuration.isPressed
            )
    }
}

private extension View {
    func shelfLayer(isActive: Bool) -> some View {
        opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
            .zIndex(isActive ? 1 : 0)
    }
}

private struct PlanShelfEmpty: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .light))
                .foregroundStyle(MossTheme.sage)
            Text(title)
                .font(MossTypography.font(11, weight: .semibold))
            Text(subtitle)
                .font(MossTypography.font(9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
    }
}

private struct PlanDayPage: View {
    @EnvironmentObject private var dataStore: DataStore

    private var todayPlans: [PlanEntry] {
        dataStore.plans.filter { Calendar.current.isDateInToday($0.scheduledAt) }
    }

    private var todaySessions: [FocusSession] {
        dataStore.sessions.filter {
            Calendar.current.isDateInToday($0.startedAt) && $0.status == .completed
        }
    }

    private var plannedMinutes: Int {
        todayPlans.filter { $0.status == .planned }.reduce(0) { $0 + $1.estimatedMinutes }
    }

    private var focusedDuration: TimeInterval {
        todaySessions.reduce(0) { $0 + $1.actualFocusDuration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                journalDateHeader(
                    eyebrow: Date.now.formatted(.dateTime.weekday(.wide)),
                    title: Date.now.formatted(.dateTime.month(.wide).day())
                )

                Text("今天的一页")
                    .font(MossTypography.editorial(35, weight: .semibold))

                HStack(spacing: 12) {
                    PlanMetric(value: "\(todayPlans.filter { $0.status == .planned }.count)", label: "等待开始", symbol: "circle.dashed")
                    PlanMetric(value: "\(plannedMinutes)m", label: "计划投入", symbol: "hourglass")
                    PlanMetric(value: focusedDuration.compactDuration, label: "已经专注", symbol: "leaf.fill")
                }

                if todaySessions.isEmpty {
                    MossCard(kind: .quiet) {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 22))
                                .foregroundStyle(MossTheme.apricot)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("还没有开始，也没有关系")
                                    .font(MossTypography.editorial(17, weight: .semibold))
                                Text("选一条计划，先做五分钟。Moss 会把结果写回这一页。")
                                    .font(MossTypography.font(11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今天留下的痕迹")
                            .font(MossTypography.editorial(20, weight: .semibold))
                        ForEach(todaySessions.sorted { $0.startedAt > $1.startedAt }.prefix(5)) { session in
                            FocusJournalRow(session: session)
                        }
                    }
                }
            }
            .padding(34)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

private struct PlanEntryPage: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    let plan: PlanEntry
    let onEdit: () -> Void
    @State private var isConfirmingDelete = false

    private var linkedTask: FocusTask? {
        guard let id = plan.linkedTaskID else { return nil }
        return dataStore.tasks.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    journalDateHeader(
                        eyebrow: plan.scheduledAt.formatted(.dateTime.weekday(.wide)),
                        title: plan.scheduledAt.formatted(.dateTime.year().month(.wide).day())
                    )
                    Spacer()
                    PlanStatusBadge(status: plan.status)
                }

                Text(plan.title)
                    .font(MossTypography.editorial(38, weight: .semibold))
                    .tracking(-0.6)
                    .textSelection(.enabled)

                if !plan.note.isEmpty {
                    Text(plan.note)
                        .font(MossTypography.font(14))
                        .lineSpacing(6)
                        .foregroundStyle(.primary.opacity(0.86))
                        .textSelection(.enabled)
                } else {
                    Text("没有额外说明。留白也可以是一种计划。")
                        .font(MossTypography.font(13))
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.5)

                HStack(spacing: 12) {
                    PlanMetric(value: "\(plan.estimatedMinutes)m", label: "预计投入", symbol: "hourglass")
                    PlanMetric(
                        value: linkedTask?.title ?? "开始时创建",
                        label: "关联任务",
                        symbol: "link"
                    )
                }

                HStack(spacing: 10) {
                    if plan.status == .planned {
                        Button {
                            start(.ignition)
                        } label: {
                            Label("先做 5 分钟", systemImage: "flame.fill")
                        }
                        .buttonStyle(CapsuleButtonStyle(tint: MossTheme.apricot))
                        .disabled(store.phase != .idle)

                        Button {
                            start(.standard)
                        } label: {
                            Label("开始专注", systemImage: "play.fill")
                        }
                        .buttonStyle(CapsuleButtonStyle(prominent: true))
                        .disabled(store.phase != .idle)

                        Button("标记完成") {
                            dataStore.setPlanStatus(id: plan.id, status: .completed)
                        }
                        .buttonStyle(CapsuleButtonStyle())
                    } else {
                        Button("恢复为待开始") {
                            dataStore.setPlanStatus(id: plan.id, status: .planned)
                        }
                        .buttonStyle(CapsuleButtonStyle())
                    }

                    Spacer()

                    Button("编辑", action: onEdit)
                        .buttonStyle(CapsuleButtonStyle())

                    Menu {
                        if plan.status != .skipped {
                            Button("暂时搁置") {
                                dataStore.setPlanStatus(id: plan.id, status: .skipped)
                            }
                        }
                        Divider()
                        Button("删除计划", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 30, height: 30)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                if store.phase != .idle {
                    Label("已有专注正在进行，结束后才能从计划启动新的专注。", systemImage: "timer")
                        .font(MossTypography.font(10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(38)
            .frame(maxWidth: 780, alignment: .leading)
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
            Text("只删除这条计划，不会删除已关联的任务或专注记录。")
        }
    }

    private func start(_ mode: FocusMode) {
        guard store.phase == .idle else { return }
        let task = dataStore.task(for: plan)
        let duration = mode == .ignition ? 5 * 60 : TimeInterval(plan.estimatedMinutes * 60)
        store.start(task: task, mode: mode, duration: duration)
    }
}

private struct JournalRecordPage: View {
    @EnvironmentObject private var dataStore: DataStore
    let record: JournalRecord
    let onEdit: (() -> Void)?
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    journalDateHeader(
                        eyebrow: record.entryDate.formatted(.dateTime.weekday(.wide)),
                        title: record.entryDate.formatted(.dateTime.year().month(.wide).day())
                    )
                    Spacer()
                    Label(
                        record.source == .appleJournal ? "Apple 手记导入" : "Moss 记录",
                        systemImage: record.source == .appleJournal ? "apple.logo" : "leaf.fill"
                    )
                    .font(MossTypography.font(9, weight: .bold))
                    .foregroundStyle(MossTheme.sage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(MossTheme.sage.opacity(0.09), in: Capsule())
                }

                Text(record.title)
                    .font(MossTypography.editorial(36, weight: .semibold))
                    .textSelection(.enabled)

                Text(record.body)
                    .font(MossTypography.font(14))
                    .lineSpacing(7)
                    .foregroundStyle(.primary.opacity(0.88))
                    .textSelection(.enabled)

                Divider().opacity(0.5)

                HStack {
                    if let fileName = record.importedFileName {
                        Label(fileName, systemImage: "doc")
                            .font(MossTypography.font(9))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let onEdit {
                        Button("编辑", action: onEdit)
                            .buttonStyle(CapsuleButtonStyle())
                    }
                    Button(
                        record.source == .appleJournal ? "移除这份导入" : "删除这篇手记",
                        role: .destructive
                    ) {
                        isConfirmingDelete = true
                    }
                    .buttonStyle(CapsuleButtonStyle(tint: MossTheme.brick))
                }
            }
            .padding(38)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .confirmationDialog(
            record.source == .appleJournal
                ? "移除「\(record.title)」？"
                : "删除「\(record.title)」？",
            isPresented: $isConfirmingDelete
        ) {
            Button(
                record.source == .appleJournal ? "移除导入" : "删除手记",
                role: .destructive
            ) {
                dataStore.deleteJournalRecord(id: record.id)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(
                record.source == .appleJournal
                    ? "只移除 Moss 中的副本，不会影响 Apple 手记或原始导出文件。"
                    : "这篇 Moss 手记会从本机记录中删除。"
            )
        }
    }
}

private struct MossDatePicker: View {
    @Binding var selection: Date
    @State private var isShowingCalendar = false

    var body: some View {
        Button {
            isShowingCalendar.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MossTheme.sage)
                    .frame(width: 31, height: 31)
                    .background(
                        MossTheme.sage.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeDayTitle)
                        .font(MossTypography.font(9, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                    Text(selection.formatted(.dateTime.year().month().day()))
                        .font(MossTypography.font(12, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isShowingCalendar
                            ? MossTheme.sage.opacity(0.38)
                            : MossTheme.hairline
                    )
            )
        }
        .buttonStyle(MossJellyPlainButtonStyle())
        .accessibilityLabel("记录日期，\(selection.formatted(.dateTime.year().month().day()))")
        .popover(isPresented: $isShowingCalendar, arrowEdge: .bottom) {
            MossCalendar(selection: $selection) {
                isShowingCalendar = false
            }
        }
    }

    private var relativeDayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selection) {
            return "今天"
        }
        if calendar.isDateInYesterday(selection) {
            return "昨天"
        }
        if calendar.isDateInTomorrow(selection) {
            return "明天"
        }
        return selection.formatted(.dateTime.weekday(.wide))
    }
}

private struct MossCalendar: View {
    @Binding var selection: Date
    let onSelect: () -> Void

    @State private var displayedMonth: Date

    private let columns = Array(
        repeating: GridItem(.fixed(34), spacing: 4),
        count: 7
    )
    private let weekdayTitles = ["日", "一", "二", "三", "四", "五", "六"]

    init(selection: Binding<Date>, onSelect: @escaping () -> Void) {
        _selection = selection
        self.onSelect = onSelect
        _displayedMonth = State(
            initialValue: Calendar.current.dateInterval(
                of: .month,
                for: selection.wrappedValue
            )?.start ?? selection.wrappedValue
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                .help("上个月")

                Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                    .font(MossTypography.editorial(17, weight: .semibold))
                    .frame(maxWidth: .infinity)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                .help("下个月")
            }

            HStack(spacing: 7) {
                quickDateButton(
                    "昨天",
                    date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
                )
                quickDateButton("今天", date: .now)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdayTitles, id: \.self) { title in
                    Text(title)
                        .font(MossTypography.font(9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 22)
                }

                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    dayButton(date)
                }
            }
        }
        .padding(16)
        .frame(width: 294)
        .background(
            LinearGradient(
                colors: [
                    MossTheme.card,
                    MossTheme.sage.opacity(0.045),
                    MossTheme.card
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onChange(of: selection) { _, date in
            displayedMonth = monthStart(for: date)
        }
    }

    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let monthStart = monthStart(for: displayedMonth)
        let weekdayOffset = calendar.component(.weekday, from: monthStart) - 1
        let gridStart = calendar.date(
            byAdding: .day,
            value: -weekdayOffset,
            to: monthStart
        ) ?? monthStart
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    @ViewBuilder
    private func dayButton(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)
        let isInMonth = calendar.isDate(
            date,
            equalTo: displayedMonth,
            toGranularity: .month
        )

        Button {
            selection = datePreservingTime(date)
            onSelect()
        } label: {
            Text(String(Calendar.current.component(.day, from: date)))
                .font(MossTypography.font(11, weight: isSelected ? .bold : .medium))
                .foregroundStyle(
                    isSelected
                        ? MossTheme.current.accentForeground
                        : isInMonth ? Color.primary : Color.secondary.opacity(0.45)
                )
                .frame(width: 32, height: 32)
                .background(
                    isSelected ? MossTheme.sage : Color.clear,
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            isToday && !isSelected
                                ? MossTheme.sage.opacity(0.65)
                                : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
        .accessibilityLabel(date.formatted(.dateTime.year().month().day()))
    }

    private func quickDateButton(_ title: String, date: Date) -> some View {
        Button(title) {
            selection = datePreservingTime(date)
            onSelect()
        }
        .font(MossTypography.font(9, weight: .semibold))
        .buttonStyle(CapsuleButtonStyle())
    }

    private func moveMonth(by offset: Int) {
        displayedMonth = Calendar.current.date(
            byAdding: .month,
            value: offset,
            to: displayedMonth
        ) ?? displayedMonth
    }

    private func monthStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func datePreservingTime(_ date: Date) -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: selection)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: date
        ) ?? date
    }
}

private struct JournalEditorView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    private enum Field {
        case title
        case body
    }

    let record: JournalRecord?
    let onSave: (JournalRecord) -> Void
    @State private var title: String
    @State private var bodyText: String
    @State private var entryDate: Date
    @FocusState private var focusedField: Field?

    init(
        record: JournalRecord? = nil,
        onSave: @escaping (JournalRecord) -> Void
    ) {
        self.record = record
        self.onSave = onSave
        _title = State(initialValue: record?.title ?? "")
        _bodyText = State(initialValue: record?.body ?? "")
        _entryDate = State(initialValue: record?.entryDate ?? .now)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record == nil ? "写一篇手记" : "编辑手记")
                        .font(MossTypography.editorial(25, weight: .semibold))
                    Text("不必完整，先留下此刻真正重要的事。")
                        .font(MossTypography.font(10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(CapsuleButtonStyle())
                Button("保存手记") {
                    save()
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
                .disabled(!canSave)
            }
            .padding(24)

            Divider().opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        MossDatePicker(selection: $entryDate)

                        Spacer()

                        Label("仅保存在本机", systemImage: "lock.fill")
                            .font(MossTypography.font(9, weight: .semibold))
                            .foregroundStyle(MossTheme.sage)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(MossTheme.sage.opacity(0.08), in: Capsule())
                    }

                    TextField("标题（可以稍后再写）", text: $title)
                        .textFieldStyle(.plain)
                        .font(MossTypography.editorial(30, weight: .semibold))
                        .padding(.vertical, 4)
                        .focused($focusedField, equals: .title)

                    Rectangle()
                        .fill(MossTheme.sage.opacity(0.24))
                        .frame(width: 48, height: 2)

                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("从此刻最想记住的一句话开始……")
                                .font(MossTypography.font(14))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 19)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $bodyText)
                            .font(MossTypography.font(14))
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .focused($focusedField, equals: .body)
                            .padding(14)
                    }
                    .frame(minHeight: 330)
                    .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 17))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(
                                focusedField == .body
                                    ? MossTheme.sage.opacity(0.38)
                                    : MossTheme.hairline
                            )
                    )
                }
                .padding(28)
            }
        }
        .frame(width: 680, height: 650)
        .background(
            LinearGradient(
                colors: [
                    MossTheme.paper,
                    MossTheme.sage.opacity(0.035),
                    MossTheme.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .body
            }
        }
    }

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let typedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = typedTitle.isEmpty ? automaticTitle(from: cleanBody) : typedTitle
        let savedRecord: JournalRecord
        if var record {
            record.title = cleanTitle
            record.body = cleanBody
            record.entryDate = entryDate
            dataStore.updateJournalRecord(record)
            savedRecord = record
        } else {
            let newRecord = JournalRecord(
                title: cleanTitle,
                body: cleanBody,
                entryDate: entryDate,
                source: .moss
            )
            dataStore.addJournalRecord(newRecord)
            savedRecord = newRecord
        }
        onSave(savedRecord)
        dismiss()
    }

    private func automaticTitle(from body: String) -> String {
        let firstLine = body
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let firstLine else {
            return entryDate.formatted(.dateTime.month().day()) + "的手记"
        }
        if firstLine.count <= 24 {
            return firstLine
        }
        return String(firstLine.prefix(24)) + "…"
    }
}

private struct PlanJournalOverview: View {
    @EnvironmentObject private var dataStore: DataStore
    let onWrite: () -> Void

    private var recentSessions: [FocusSession] {
        dataStore.sessions
            .filter { $0.status == .completed }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                journalDateHeader(eyebrow: "MOSS", title: "专注留下的手记")
                Text("这里把你主动导入的手记，与 Moss 的真实行动放在同一条时间里。")
                    .font(MossTypography.editorial(24, weight: .semibold))
                    .frame(maxWidth: 620, alignment: .leading)

                Button(action: onWrite) {
                    HStack(spacing: 14) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(MossTheme.sage)
                            .frame(width: 38, height: 38)
                            .background(
                                MossTheme.sage.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("写下此刻")
                                .font(MossTypography.editorial(17, weight: .semibold))
                            Text("直接开始写；标题可以留到最后。")
                                .font(MossTypography.font(10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MossTheme.sage)
                    }
                    .padding(14)
                    .background(
                        MossTheme.sage.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 17)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(MossTheme.sage.opacity(0.18))
                    )
                }
                .buttonStyle(MossJellyPlainButtonStyle())

                if recentSessions.isEmpty {
                    ContentUnavailableView(
                        "还没有专注记录",
                        systemImage: "leaf",
                        description: Text("完成一次专注后，它会成为这里的一条记录。")
                    )
                    .frame(minHeight: 260)
                } else {
                    VStack(spacing: 10) {
                        ForEach(recentSessions.prefix(8)) { session in
                            FocusJournalRow(session: session)
                        }
                    }
                }
            }
            .padding(38)
            .frame(maxWidth: 780, alignment: .leading)
        }
    }
}

private struct FocusJournalRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(session.startedAt.formatted(.dateTime.day()))
                    .font(MossTypography.editorial(19, weight: .semibold))
                Text(session.startedAt.formatted(.dateTime.month(.abbreviated)))
                    .font(MossTypography.font(8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 38)

            Rectangle()
                .fill(MossTheme.sage.opacity(0.24))
                .frame(width: 1, height: 39)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.taskTitle)
                    .font(MossTypography.font(12, weight: .semibold))
                Text("\(session.projectTitle) · \(session.actualFocusDuration.compactDuration)")
                    .font(MossTypography.font(9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MossTheme.mint)
        }
        .padding(12)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(MossTheme.hairline))
    }
}

private struct PlanMetric: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MossTheme.sage)
                .frame(width: 32, height: 32)
                .background(MossTheme.sage.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(MossTypography.font(14, weight: .bold))
                    .lineLimit(1)
                Text(label)
                    .font(MossTypography.font(9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(MossTheme.hairline))
    }
}

private struct PlanStatusBadge: View {
    let status: PlanStatus

    var body: some View {
        Label(status.title, systemImage: symbol)
            .font(MossTypography.font(9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.09), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .planned: MossTheme.apricot
        case .completed: MossTheme.mint
        case .skipped: .secondary
        }
    }

    private var symbol: String {
        switch status {
        case .planned: "circle.dashed"
        case .completed: "checkmark.circle.fill"
        case .skipped: "pause.circle"
        }
    }
}

private func journalDateHeader(eyebrow: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(eyebrow.uppercased())
            .font(MossTypography.font(9, weight: .bold))
            .tracking(1.25)
            .foregroundStyle(MossTheme.sage)
        Text(title)
            .font(MossTypography.font(12, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct PlanEditorView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    let plan: PlanEntry?
    @State private var title: String
    @State private var note: String
    @State private var scheduledAt: Date
    @State private var estimatedMinutes: Int
    @State private var linkedTaskID: UUID?

    init(
        plan: PlanEntry? = nil,
        initialScheduledAt: Date = .now,
        initialEstimatedMinutes: Int = 25
    ) {
        self.plan = plan
        _title = State(initialValue: plan?.title ?? "")
        _note = State(initialValue: plan?.note ?? "")
        _scheduledAt = State(initialValue: plan?.scheduledAt ?? initialScheduledAt)
        _estimatedMinutes = State(initialValue: plan?.estimatedMinutes ?? initialEstimatedMinutes)
        _linkedTaskID = State(initialValue: plan?.linkedTaskID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan == nil ? "写下计划" : "编辑这一页")
                        .font(MossTypography.editorial(24, weight: .semibold))
                    Text("计划只需要清楚到足以开始。")
                        .font(MossTypography.font(10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(CapsuleButtonStyle())
                Button(plan == nil ? "存入计划" : "保存") {
                    save()
                }
                .buttonStyle(CapsuleButtonStyle(prominent: true))
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("要做什么")
                            .font(MossTypography.font(10, weight: .bold))
                            .foregroundStyle(.secondary)
                        TextField("例如：整理实验结果并写下三个结论", text: $title)
                            .textFieldStyle(.plain)
                            .font(MossTypography.editorial(24, weight: .semibold))
                            .padding(14)
                            .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(MossTheme.hairline))
                    }

                    HStack(alignment: .top, spacing: 14) {
                        editorBlock("安排在") {
                            HStack(spacing: 9) {
                                MossDatePicker(selection: $scheduledAt)
                                Text(scheduledAt.formatted(.dateTime.hour().minute()))
                                    .font(MossTypography.font(12, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(MossTheme.sage)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .background(
                                        MossTheme.sage.opacity(0.09),
                                        in: RoundedRectangle(cornerRadius: 11)
                                    )
                            }
                        }

                        editorBlock("预计投入") {
                            HStack {
                                Button {
                                    estimatedMinutes = max(5, estimatedMinutes - 5)
                                } label: {
                                    Image(systemName: "minus")
                                }
                                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                                .disabled(estimatedMinutes <= 5)

                                Spacer()
                                Text("\(estimatedMinutes) 分钟")
                                    .font(MossTypography.font(12, weight: .semibold))
                                    .monospacedDigit()
                                Spacer()

                                Button {
                                    estimatedMinutes = min(240, estimatedMinutes + 5)
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.90))
                                .disabled(estimatedMinutes >= 240)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MossTheme.hairline))
                        }
                    }

                    editorBlock("关联专注任务") {
                        Menu {
                            Button {
                                linkedTaskID = nil
                            } label: {
                                Label(
                                    "开始时自动创建",
                                    systemImage: linkedTaskID == nil ? "checkmark" : "plus.circle"
                                )
                            }
                            if !dataStore.startableTasks.isEmpty {
                                Divider()
                            }
                            ForEach(dataStore.startableTasks) { task in
                                Button {
                                    linkedTaskID = task.id
                                } label: {
                                    Label(
                                        "\(task.title) · \(task.category)",
                                        systemImage: linkedTaskID == task.id ? "checkmark" : "circle"
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "link")
                                    .foregroundStyle(MossTheme.sage)
                                Text(linkedTaskTitle)
                                    .font(MossTypography.font(12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MossTheme.hairline))
                        }
                        .menuStyle(.borderlessButton)
                    }

                    editorBlock("写一点上下文") {
                        TextEditor(text: $note)
                            .font(MossTypography.font(13))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(10)
                            .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 15))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(MossTheme.hairline))
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 640, height: 610)
        .background(MossTheme.paper)
    }

    private func editorBlock<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MossTypography.font(10, weight: .bold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var linkedTaskTitle: String {
        guard let linkedTaskID,
              let task = dataStore.startableTasks.first(where: { $0.id == linkedTaskID }) else {
            return "开始时自动创建专注任务"
        }
        return "\(task.title) · \(task.category)"
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if var plan {
            plan.title = cleanTitle
            plan.note = cleanNote
            plan.scheduledAt = scheduledAt
            plan.estimatedMinutes = estimatedMinutes
            plan.linkedTaskID = linkedTaskID
            dataStore.updatePlan(plan)
        } else {
            dataStore.addPlan(PlanEntry(
                title: cleanTitle,
                note: cleanNote,
                scheduledAt: scheduledAt,
                estimatedMinutes: estimatedMinutes,
                linkedTaskID: linkedTaskID
            ))
        }
        dismiss()
    }
}
