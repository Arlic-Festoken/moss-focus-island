import Foundation

struct JournalEditorDraft: Identifiable {
    let id = UUID()
    var title: String
    var body: String
    var entryDate: Date

    static func blank(at date: Date = .now) -> JournalEditorDraft {
        JournalEditorDraft(title: "", body: "", entryDate: date)
    }
}

enum PlanJournalSearch {
    static func matches(
        plan: PlanEntry,
        linkedTaskTitle: String?,
        query: String
    ) -> Bool {
        matches(
            fields: [plan.title, plan.note, linkedTaskTitle ?? ""],
            query: query
        )
    }

    static func matches(record: JournalRecord, query: String) -> Bool {
        matches(fields: [record.title, record.body], query: query)
    }

    private static func matches(fields: [String], query: String) -> Bool {
        let tokens = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !tokens.isEmpty else { return true }
        let searchableText = fields.joined(separator: "\n")
        return tokens.allSatisfy { searchableText.localizedStandardContains($0) }
    }
}

enum DailyJournalDraftBuilder {
    static func make(
        for date: Date = .now,
        plans: [PlanEntry],
        sessions: [FocusSession],
        calendar: Calendar = .current
    ) -> JournalEditorDraft {
        let dayPlans = plans.filter {
            calendar.isDate($0.scheduledAt, inSameDayAs: date)
        }
        let daySessions = sessions.filter {
            calendar.isDate($0.startedAt, inSameDayAs: date)
                && $0.status == .completed
        }
        let completedPlans = dayPlans.filter { $0.status == .completed }
        let pendingPlans = dayPlans.filter { $0.status == .planned }
        let skippedPlans = dayPlans.filter { $0.status == .skipped }
        let focusedDuration = daySessions.reduce(0) {
            $0 + $1.actualFocusDuration
        }
        let focusTitles = uniqueTitles(
            daySessions.map(\.taskTitle) + completedPlans.map(\.title)
        )

        var lines: [String] = []
        if daySessions.isEmpty {
            lines.append("今天还没有完成专注记录。")
        } else {
            lines.append(
                "今天完成了 \(daySessions.count) 段专注，共 \(focusedDuration.compactDuration)。"
            )
        }

        if dayPlans.isEmpty {
            lines.append("今天没有写入计划。")
        } else {
            var planFacts = [
                "完成 \(completedPlans.count) 件",
                "仍有 \(pendingPlans.count) 件等待"
            ]
            if !skippedPlans.isEmpty {
                planFacts.append("\(skippedPlans.count) 件搁置")
            }
            lines.append("计划 \(dayPlans.count) 件：\(planFacts.joined(separator: "，"))。")
        }

        if !focusTitles.isEmpty {
            lines.append("今天投入在：\(focusTitles.joined(separator: "、"))。")
        }

        lines.append("")
        lines.append("值得记住：")
        lines.append("- ")
        lines.append("")
        lines.append("下一步：")
        lines.append("- ")

        return JournalEditorDraft(
            title: date.formatted(.dateTime.month().day()) + " · 今日收束",
            body: lines.joined(separator: "\n"),
            entryDate: date
        )
    }

    private static func uniqueTitles(_ titles: [String]) -> [String] {
        var seen = Set<String>()
        return titles.compactMap { title in
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty, seen.insert(cleanTitle).inserted else {
                return nil
            }
            return cleanTitle
        }
    }
}

extension PlanEntry {
    func isOverdue(
        relativeTo date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        status == .planned
            && scheduledAt < calendar.startOfDay(for: date)
    }
}
