import SwiftUI

struct FocusCompletionView: View {
    let receipt: FocusCompletionReceipt
    @AppStorage("growthTheme") private var growthThemeRaw = GrowthTheme.douluo.rawValue

    private var growthTheme: GrowthTheme {
        GrowthTheme(rawValue: growthThemeRaw) ?? .douluo
    }

    var body: some View {
        MossCard(padding: 17, kind: .hero) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(MossTheme.mint)
                    Text(growthTheme == .douluo ? "本次修炼已经完成" : "这一段已经落地")
                        .font(MossTypography.font(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(receipt.completionCount) \(growthTheme == .douluo ? "次" : "段")")
                        .font(MossTypography.font(10, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                }

                Text("+\(receipt.focusedDuration.compactDuration)")
                    .font(MossTypography.editorial(31, weight: .semibold))
                    .monospacedDigit()

                VStack(spacing: 7) {
                    receiptRow(
                        label: receipt.taskTitle,
                        value: receipt.taskTotal.compactDuration
                    )
                    receiptRow(
                        label: growthTheme == .douluo ? "总修炼" : "全部积累",
                        value: receipt.overallTotal.compactDuration
                    )
                }

                Divider().opacity(0.6)

                if let achievement = receipt.unlockedAchievement {
                    let presentation = growthTheme.achievementPresentation(for: achievement)
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                "\(growthTheme == .douluo ? "新功勋" : "新里程碑")"
                                    + " · \(presentation.title)"
                            )
                                .font(MossTypography.font(12, weight: .bold))
                            Text(presentation.subtitle)
                                .font(MossTypography.font(10))
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: presentation.symbol)
                            .foregroundStyle(MossTheme.apricot)
                    }
                } else if let next = receipt.nextAchievement {
                    let presentation = growthTheme.achievementPresentation(for: next)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(growthTheme.nextMilestonePrefix) · \(presentation.title)")
                            Spacer()
                            Text("\(Int((next.progress * 100).rounded()))%")
                        }
                        .font(MossTypography.font(10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        ProgressView(value: next.progress)
                            .tint(MossTheme.sage)
                    }
                }
            }
        }
        .frame(width: 310)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func receiptRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(MossTypography.font(11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(MossTypography.font(12, weight: .bold))
                .monospacedDigit()
        }
    }

    private var accessibilitySummary: String {
        var parts = [
            "\(growthTheme == .douluo ? "本次修炼" : "本段专注") \(receipt.focusedDuration.chineseDuration)",
            "\(receipt.taskTitle) 累计 \(receipt.taskTotal.chineseDuration)",
            "\(growthTheme == .douluo ? "总修炼" : "全部累计") \(receipt.overallTotal.chineseDuration)"
        ]
        if let achievement = receipt.unlockedAchievement {
            let presentation = growthTheme.achievementPresentation(for: achievement)
            parts.append("解锁 \(presentation.title)")
        } else if let next = receipt.nextAchievement {
            let presentation = growthTheme.achievementPresentation(for: next)
            parts.append("\(growthTheme.nextMilestonePrefix) \(presentation.title)")
        }
        return parts.joined(separator: "，")
    }
}
