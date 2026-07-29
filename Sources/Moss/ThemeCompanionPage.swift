import SwiftUI

struct ThemeCompanionPage: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var dataStore: DataStore
    @AppStorage("growthTheme") private var growthThemeRaw = GrowthTheme.douluo.rawValue
    @AppStorage("douluoAvatarForm") private var avatarFormRaw = DouluoAvatarForm.soulMaster.rawValue
    @State private var dialogueIndex = 0

    private var theme: GrowthTheme {
        GrowthTheme(rawValue: growthThemeRaw) ?? .douluo
    }

    private var avatarForm: DouluoAvatarForm {
        DouluoAvatarForm(rawValue: avatarFormRaw) ?? .soulMaster
    }

    private var snapshot: ThemeAvatarSnapshot {
        ThemeAvatarSnapshot(
            analytics: dataStore.analyticsSnapshot,
            projects: dataStore.projects,
            tasks: dataStore.tasks,
            sessions: dataStore.sessions
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                pageHeader
                companionStage

                if theme == .douluo && avatarForm == .soulMaster {
                    equipmentBoard
                    organizationBoard
                } else {
                    alternateFormBoard
                }
            }
            .padding(28)
            .frame(maxWidth: 1160, alignment: .leading)
        }
    }

    private var pageHeader: some View {
        MossPageHeader(
            eyebrow: "Companion",
            title: theme == .douluo ? "魂师伙伴" : "岛屿伙伴",
            subtitle: "这是完整的角色板块。点击角色可以互动，未来的动画也会在这里呈现。"
        ) {
            if theme == .douluo {
                Picker("形态", selection: $avatarFormRaw) {
                    ForEach(DouluoAvatarForm.allCases) { form in
                        Label(form.title, systemImage: form.symbol)
                            .tag(form.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 230)
            }
        }
    }

    private var companionStage: some View {
        MossCard(kind: .hero) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 34) {
                    interactiveAvatar
                        .frame(width: 390)
                    companionStatus
                }
                VStack(alignment: .leading, spacing: 22) {
                    interactiveAvatar
                        .frame(maxWidth: .infinity)
                    companionStatus
                }
            }
        }
    }

    private var interactiveAvatar: some View {
        Button {
            dialogueIndex = (dialogueIndex + 1) % dialogueLines.count
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    avatarTint.opacity(0.24),
                                    avatarTint.opacity(0.04),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 145
                            )
                        )
                        .frame(width: 310, height: 310)

                    if theme == .douluo && avatarForm == .soulMaster {
                        ForEach(snapshot.equippedSoulRings.indices, id: \.self) { index in
                            Circle()
                                .stroke(
                                    index == 0 ? MossTheme.sage : TitleGroup.exploration.color,
                                    style: StrokeStyle(
                                        lineWidth: 3,
                                        dash: [7 + CGFloat(index), 6]
                                    )
                                )
                                .frame(
                                    width: 276 - CGFloat(index * 19),
                                    height: 276 - CGFloat(index * 19)
                                )
                                .rotationEffect(.degrees(Double(index * 23)))
                        }
                    }

                    Text(avatarEmoji)
                        .font(.system(size: 128))
                        .shadow(color: avatarTint.opacity(0.25), radius: 24, y: 12)

                    Text("动画预留")
                        .font(MossTypography.font(9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                        .offset(x: 105, y: -112)
                }

                Text("“\(dialogueLines[dialogueIndex])”")
                    .font(MossTypography.font(14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: 330)

                Label("点击和伙伴说话", systemImage: "hand.tap.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MossJellyPlainButtonStyle(pressedScale: 0.975))
        .mossJellyHover(scale: 1.012, lift: 2, glow: 0.10)
        .accessibilityLabel("\(companionName)，点击互动")
    }

    private var companionStatus: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(companionName)
                    .font(MossTypography.editorial(28, weight: .semibold))
                Text(companionIdentity)
                    .font(MossTypography.font(13, weight: .semibold))
                    .foregroundStyle(avatarTint)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                spacing: 10
            ) {
                companionMetric("当前状态", liveStatus, "bolt.heart.fill")
                companionMetric("累计修炼", snapshot.analytics.totalFocus.compactDuration, "hourglass")
                if theme == .douluo && avatarForm == .soulMaster {
                    companionMetric("综合战力", snapshot.combatPower.formatted(), "flame.fill")
                    companionMetric("当前舞台", snapshot.currentAffiliation, "building.2.fill")
                } else if theme == .douluo {
                    companionMetric("魂兽年限", snapshot.rank.formattedSoulRingYears, "pawprint.fill")
                } else {
                    companionMetric("岛屿阶段", snapshot.islandStage, "mountain.2.fill")
                }
            }

            if let recommendation = snapshot.trainingRecommendations.first,
               let task = snapshot.tasks.first(where: { $0.id == recommendation.taskID }),
               theme == .douluo,
               avatarForm == .soulMaster {
                VStack(alignment: .leading, spacing: 7) {
                    Text("伙伴建议")
                        .font(MossTypography.font(10, weight: .bold))
                        .foregroundStyle(MossTheme.sage)
                    Text(recommendation.taskTitle)
                        .font(MossTypography.font(16, weight: .bold))
                    Text(recommendation.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("一起开始修炼 · 预计 +\(recommendation.expectedPowerGain)") {
                        store.start(task: task)
                    }
                    .buttonStyle(CapsuleButtonStyle(prominent: true))
                    .disabled(store.phase != .idle)
                }
                .padding(13)
                .background(MossTheme.sage.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            } else {
                Text(statusHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var equipmentBoard: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 16) {
                boardTitle(
                    "魂师配置",
                    subtitle: "个人成长仍是主角；这里把当前记录解释为武魂、魂环、魂灵与装备。"
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: 11)],
                    spacing: 11
                ) {
                    equipmentTile(
                        emoji: "✨",
                        title: snapshot.martialSouls.count > 1 ? "双生武魂" : "武魂",
                        value: snapshot.martialSouls.isEmpty
                            ? "等待觉醒"
                            : snapshot.martialSouls.map(\.group.title).joined(separator: " × ")
                    )
                    equipmentTile(
                        emoji: "⭕",
                        title: "魂环",
                        value: "\(snapshot.equippedSoulRings.count) / \(snapshot.soulRingCapacity) 已装备"
                    )
                    equipmentTile(
                        emoji: "🕊️",
                        title: "魂灵",
                        value: snapshot.activeSoulSpirits.isEmpty
                            ? "暂无活跃大项目"
                            : "\(snapshot.activeSoulSpirits.count) 位伙伴"
                    )
                    equipmentTile(
                        emoji: "🦴",
                        title: "魂骨",
                        value: snapshot.soulBoneSlots.isEmpty
                            ? "尚未获得"
                            : snapshot.soulBoneSlots.joined(separator: " · ")
                    )
                    equipmentTile(emoji: "🛡️", title: "斗铠", value: snapshot.battleArmorTitle)
                    equipmentTile(emoji: "🤖", title: "机甲", value: snapshot.mechaTitle)
                }

                if !snapshot.equippedSoulRings.isEmpty {
                    Divider().opacity(0.55)
                    VStack(alignment: .leading, spacing: 9) {
                        Text("当前魂环")
                            .font(MossTypography.font(11, weight: .bold))
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 160), spacing: 9)],
                            spacing: 9
                        ) {
                            ForEach(snapshot.equippedSoulRings) { ring in
                                HStack {
                                    Text("⭕")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(ring.title)
                                            .font(MossTypography.font(11, weight: .bold))
                                        Text(ring.rank.formattedSoulRingYears)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
    }

    private var organizationBoard: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 16) {
                boardTitle(
                    "势力舞台",
                    subtitle: "学院、传灵塔、战神殿、帝国与大陆只承接更大规模的长期目标。"
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(snapshot.organizationNodes) { node in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: node.symbol)
                                    .foregroundStyle(node.isUnlocked ? MossTheme.sage : .secondary)
                                Text(node.title)
                                    .font(MossTypography.font(11, weight: .bold))
                                Spacer()
                                Text(node.isUnlocked ? "已进入" : "未解锁")
                                    .font(.caption2)
                                    .foregroundStyle(node.isUnlocked ? MossTheme.sage : .secondary)
                            }
                            Text(node.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            ProgressView(value: node.progress)
                                .tint(node.isUnlocked ? MossTheme.sage : MossTheme.mint)
                        }
                        .padding(11)
                        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
            }
        }
    }

    private var alternateFormBoard: some View {
        MossCard {
            VStack(alignment: .leading, spacing: 14) {
                boardTitle(
                    theme == .douluo ? "魂兽图鉴" : "岛屿图鉴",
                    subtitle: theme == .douluo
                        ? "魂兽形态只计算总修炼年限，不装备魂环、魂骨或机甲。"
                        : "岛屿形态会把投入解释为地貌、区域和成长痕迹。"
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), spacing: 10)],
                    spacing: 10
                ) {
                    companionMetric("活跃日", "\(snapshot.analytics.activeDays) 天", "calendar")
                    companionMetric("最长连续", "\(snapshot.analytics.longestStreak) 天", "flame.fill")
                    companionMetric("完成修炼", "\(snapshot.analytics.completionCount) 次", "checkmark.seal.fill")
                    companionMetric(
                        theme == .douluo ? "魂兽年限" : "形成区域",
                        theme == .douluo
                            ? snapshot.rank.formattedSoulRingYears
                            : "\(snapshot.analytics.titleMetrics.count) 个",
                        theme == .douluo ? "pawprint.fill" : "map.fill"
                    )
                }
            }
        }
    }

    private func boardTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(MossTypography.editorial(21, weight: .semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func companionMetric(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(avatarTint)
                .frame(width: 30, height: 30)
                .background(avatarTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(MossTypography.font(13, weight: .bold))
                    .lineLimit(1)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
    }

    private func equipmentTile(emoji: String, title: String, value: String) -> some View {
        HStack(spacing: 11) {
            Text(emoji)
                .font(.system(size: 25))
                .frame(width: 42, height: 42)
                .background(MossTheme.quietFill, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MossTypography.font(10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(MossTypography.font(12, weight: .bold))
                    .lineLimit(2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(11)
        .background(MossTheme.quietFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .mossJellyHover(scale: 1.018, lift: 2, glow: 0.08)
    }

    private var avatarEmoji: String {
        if theme == .moss { return "🏝️" }
        return avatarForm == .soulMaster ? "🧘" : "🐉"
    }

    private var avatarTint: Color {
        if theme == .moss { return MossTheme.sage }
        return avatarForm == .soulMaster ? MossTheme.sage : TitleGroup.exploration.color
    }

    private var companionName: String {
        if theme == .moss { return snapshot.islandStage }
        return avatarForm == .soulMaster ? "你的魂师" : "你的魂兽"
    }

    private var companionIdentity: String {
        if theme == .moss {
            return "\(snapshot.analytics.titleMetrics.count) 个区域 · \(snapshot.analytics.activeDays) 个活跃日"
        }
        if avatarForm == .soulBeast {
            return "\(snapshot.rank.formattedSoulRingYears)魂兽"
        }
        return "Lv.\(snapshot.rank.level) · \(snapshot.rank.realm.title)"
    }

    private var liveStatus: String {
        switch store.phase {
        case .idle: "等待出发"
        case .preparing: "准备修炼"
        case .focusing: "共同修炼中"
        case .paused: "暂时休整"
        case .breakTime: "恢复魂力"
        case .awaitingReview: "等待复盘"
        }
    }

    private var statusHint: String {
        if store.phase != .idle {
            return "伙伴正在陪你完成当前专注流程，结束后会同步更新等级和装备。"
        }
        return "创建或恢复一个可执行的大项目后，伙伴会主动推荐下一项修炼。"
    }

    private var dialogueLines: [String] {
        if theme == .moss {
            return [
                "今天也给岛上留下一小块新地貌吧。",
                "不用一次完成整座岛，先积累这一段。",
                "你的每次专注，都会成为这里的一部分。"
            ]
        }
        if avatarForm == .soulBeast {
            return [
                "年限来自真实修炼，不来自等待。",
                "继续积累，我会变得更强。",
                "今天准备修炼哪一个领域？"
            ]
        }
        return [
            "魂力不会凭空增长，我们开始下一段修炼吧。",
            "主线很重要，但适当补充阅读和实践会获得更高协同。",
            "魂环槽位取决于等级，多余领域会先进入候选图鉴。",
            "归档不是遗忘，它会成为传灵塔中的历史记录。"
        ]
    }
}
