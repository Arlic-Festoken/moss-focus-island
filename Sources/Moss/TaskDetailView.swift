import SwiftUI

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: DataStore
    let task: FocusTask

    private var sessions: [FocusSession] {
        dataStore.sessions(for: task.id).sorted { $0.startedAt > $1.startedAt }
    }

    private var totalFocus: TimeInterval {
        sessions.reduce(0) { $0 + $1.actualFocusDuration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title).font(.title2.bold())
                        Text("\(task.category) · \(task.timerActivity.title)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("完成") { dismiss() }
                }

                HStack(spacing: 12) {
                    detailMetric("累计专注", totalFocus.chineseDuration, "timer")
                    detailMetric("完成段数", "\(sessions.count)", "checkmark.circle")
                    detailMetric("最近专注", sessions.first?.startedAt.formatted(.relative(presentation: .named)) ?? "还没有", "clock")
                }

                MossCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("专注记录").font(.headline)
                        if sessions.isEmpty {
                            Text("这个任务还没有专注记录。")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ForEach(sessions.prefix(30)) { session in
                                TimelineRow(session: session)
                                if session.id != sessions.prefix(30).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 640, height: 620)
        .background(MossTheme.paper)
    }

    private func detailMetric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).foregroundStyle(MossTheme.sage)
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MossTheme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
