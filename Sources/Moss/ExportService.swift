import AppKit
import Foundation

enum ExportFormat {
    case json
    case csv
}

struct ExportTask: Codable {
    var id: UUID
    var projectID: UUID?
    var title: String
    var category: String
    var estimatedSessions: Int
    var completedSessions: Int
    var archived: Bool
    var createdAt: Date
    var timerActivity: String
    var focusDuration: TimeInterval
    var warmupDuration: TimeInterval
    var discardThreshold: TimeInterval
}

struct ExportSession: Codable {
    var id: UUID
    var taskID: UUID
    var taskTitle: String
    var projectID: UUID?
    var projectTitle: String
    var category: String
    var startedAt: Date
    var endedAt: Date?
    var plannedDuration: TimeInterval
    var actualFocusDuration: TimeInterval
    var pausedDuration: TimeInterval
    var warmupDuration: TimeInterval
    var timerActivity: String
    var mode: String
    var status: String
    var completionState: String?
    var distractionSource: String?
    var note: String
}

struct MossExport: Codable {
    var exportedAt: Date
    var tasks: [ExportTask]
    var sessions: [ExportSession]
}

@MainActor
enum ExportService {
    static func export(tasks: [FocusTask], sessions: [FocusSession], format: ExportFormat) throws {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Moss-\(Date.now.formatted(.iso8601.year().month().day())).\(format == .json ? "json" : "csv")"
        panel.allowedContentTypes = format == .json ? [.json] : [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let data: Data
        switch format {
        case .json:
            let payload = MossExport(
                exportedAt: .now,
                tasks: tasks.map {
                    ExportTask(
                        id: $0.id,
                        projectID: $0.projectID,
                        title: $0.title,
                        category: $0.category,
                        estimatedSessions: $0.estimatedSessions,
                        completedSessions: $0.completedSessions,
                        archived: $0.archived,
                        createdAt: $0.createdAt,
                        timerActivity: $0.timerActivityRaw,
                        focusDuration: $0.focusDuration,
                        warmupDuration: $0.warmupDuration,
                        discardThreshold: $0.discardThreshold
                    )
                },
                sessions: sessions.map {
                    ExportSession(
                        id: $0.id,
                        taskID: $0.taskID,
                        taskTitle: $0.taskTitle,
                        projectID: $0.projectID,
                        projectTitle: $0.projectTitle,
                        category: $0.category,
                        startedAt: $0.startedAt,
                        endedAt: $0.endedAt,
                        plannedDuration: $0.plannedDuration,
                        actualFocusDuration: $0.actualFocusDuration,
                        pausedDuration: $0.pausedDuration,
                        warmupDuration: $0.warmupDuration,
                        timerActivity: $0.timerActivityRaw,
                        mode: $0.modeRaw,
                        status: $0.statusRaw,
                        completionState: $0.completionStateRaw,
                        distractionSource: $0.distractionSourceRaw,
                        note: $0.note
                    )
                }
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            data = try encoder.encode(payload)
        case .csv:
            let header = "id,task_id,task_title,category,started_at,ended_at,planned_seconds,focus_seconds,paused_seconds,mode,status,completion,distraction,note\n"
            let formatter = ISO8601DateFormatter()
            let rows = sessions.map { session in
                [
                    session.id.uuidString,
                    session.taskID.uuidString,
                    csv(session.taskTitle),
                    csv(session.category),
                    formatter.string(from: session.startedAt),
                    session.endedAt.map(formatter.string(from:)) ?? "",
                    String(Int(session.plannedDuration)),
                    String(Int(session.actualFocusDuration)),
                    String(Int(session.pausedDuration)),
                    session.modeRaw,
                    session.statusRaw,
                    session.completionStateRaw ?? "",
                    session.distractionSourceRaw ?? "",
                    csv(session.note)
                ].joined(separator: ",")
            }.joined(separator: "\n")
            data = Data((header + rows + "\n").utf8)
        }
        try data.write(to: url, options: .atomic)
    }

    private static func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
