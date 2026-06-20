import Foundation

struct DailyMetrics {
    var totalFocus: TimeInterval
    var completedCount: Int
    var startedCount: Int
    var completionRate: Double
    var planAccuracy: Double
    var interruptionReturnRate: Double
    var topCategory: String
    var deepestSession: FocusSession?
}

enum InsightEngine {
    static func todayMetrics(
        sessions: [FocusSession],
        interruptions: [Interruption],
        now: Date = .now
    ) -> DailyMetrics {
        let start = Calendar.current.startOfDay(for: now)
        let today = sessions.filter { $0.startedAt >= start }
        let completed = today.filter { $0.status == .completed }
        let total = completed.reduce(0) { $0 + $1.actualFocusDuration }
        let planned = completed.reduce(0) { $0 + $1.plannedDuration }
        let categories = Dictionary(grouping: completed, by: \.category)
        let top = categories.max {
            $0.value.reduce(0) { $0 + $1.actualFocusDuration }
                < $1.value.reduce(0) { $0 + $1.actualFocusDuration }
        }?.key ?? "还没有"
        let sessionIDs = Set(today.map(\.id))
        let todayInterruptions = interruptions.filter { sessionIDs.contains($0.sessionID) }

        return DailyMetrics(
            totalFocus: total,
            completedCount: completed.count,
            startedCount: today.count,
            completionRate: today.isEmpty ? 0 : Double(completed.count) / Double(today.count),
            planAccuracy: planned <= 0 ? 1 : min(2, total / planned),
            interruptionReturnRate: todayInterruptions.isEmpty
                ? 1
                : Double(todayInterruptions.filter(\.returnedToSameTask).count) / Double(todayInterruptions.count),
            topCategory: top,
            deepestSession: completed.max { $0.actualFocusDuration < $1.actualFocusDuration }
        )
    }

    static func weather(for metrics: DailyMetrics, date: Date = .now) -> (title: String, advice: String) {
        if metrics.startedCount == 0 {
            return ("薄雾待晴", "从一个明确的五分钟动作开始，不必先规划整晚。")
        }
        if metrics.completionRate > 0.8 && metrics.totalFocus >= 90 * 60 {
            return ("晴朗，节奏稳定", "保持现在的任务颗粒度，下一段先收尾，不开新坑。")
        }
        if metrics.interruptionReturnRate < 0.6 {
            return ("阵风偏多", "下一段把手机放远，只承诺完成一个清楚的小目标。")
        }
        if Calendar.current.component(.hour, from: date) >= 22 {
            return ("晴转微疲劳", "下一段做 25 分钟明确题目，避免开启复杂新任务。")
        }
        return ("多云，有上升气流", "再完成一段边界清楚的任务，今天的轨迹会更完整。")
    }

    static func feedback(for metrics: DailyMetrics) -> [String] {
        guard metrics.startedCount > 0 else {
            return [
                "今天还没有留下专注轨迹。",
                "先选一个能在五分钟内动手的动作。",
                "第一段建议：不要重做计划，直接打开材料开始。"
            ]
        }
        let deepest = metrics.deepestSession.map {
            "最深的一段是“\($0.taskTitle)”，连续专注 \($0.actualFocusDuration.compactDuration)。"
        } ?? "今天已经开始形成学习轨迹。"
        let accuracy: String
        if metrics.planAccuracy > 1.25 {
            accuracy = "实际用时明显高于预估，下一次可以把任务再切小一层。"
        } else if metrics.planAccuracy < 0.7 {
            accuracy = "实际用时低于预估，你对这类任务已经更熟练了。"
        } else {
            accuracy = "今天的任务预估与实际接近，颗粒度比较合适。"
        }
        let next = metrics.completionRate < 0.6
            ? "明天第一段先做今天未收尾的任务，不要新开任务。"
            : "明天第一段继续投入最多的“\(metrics.topCategory)”，降低重新启动成本。"
        return [deepest, accuracy, next]
    }
}
