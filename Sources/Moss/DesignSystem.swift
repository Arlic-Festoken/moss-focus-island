import SwiftUI

enum MossColorTheme: String, CaseIterable, Identifiable {
    case sage
    case ocean
    case violet
    case amber
    case rose
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sage: "鼠尾草"
        case .ocean: "海湾蓝"
        case .violet: "暮光紫"
        case .amber: "暖杏橙"
        case .rose: "山茶粉"
        case .graphite: "石墨灰"
        }
    }

    var subtitle: String {
        switch self {
        case .sage: "安静、自然"
        case .ocean: "清醒、专注"
        case .violet: "沉静、深思"
        case .amber: "温暖、有力"
        case .rose: "柔和、明亮"
        case .graphite: "克制、中性"
        }
    }

    var accent: Color {
        switch self {
        case .sage: Color(red: 0.38, green: 0.52, blue: 0.42)
        case .ocean: Color(red: 0.25, green: 0.52, blue: 0.72)
        case .violet: Color(red: 0.49, green: 0.40, blue: 0.68)
        case .amber: Color(red: 0.78, green: 0.49, blue: 0.22)
        case .rose: Color(red: 0.70, green: 0.39, blue: 0.48)
        case .graphite: Color(red: 0.40, green: 0.45, blue: 0.48)
        }
    }

    var accentDeep: Color {
        switch self {
        case .sage: Color(red: 0.19, green: 0.30, blue: 0.23)
        case .ocean: Color(red: 0.13, green: 0.27, blue: 0.39)
        case .violet: Color(red: 0.27, green: 0.21, blue: 0.40)
        case .amber: Color(red: 0.39, green: 0.24, blue: 0.11)
        case .rose: Color(red: 0.39, green: 0.20, blue: 0.25)
        case .graphite: Color(red: 0.20, green: 0.23, blue: 0.25)
        }
    }

    var completion: Color {
        switch self {
        case .sage: Color(red: 0.44, green: 0.72, blue: 0.61)
        case .ocean: Color(red: 0.40, green: 0.72, blue: 0.88)
        case .violet: Color(red: 0.66, green: 0.58, blue: 0.86)
        case .amber: Color(red: 0.90, green: 0.67, blue: 0.34)
        case .rose: Color(red: 0.86, green: 0.58, blue: 0.65)
        case .graphite: Color(red: 0.61, green: 0.68, blue: 0.70)
        }
    }

    var warm: Color {
        switch self {
        case .sage, .ocean, .violet, .graphite:
            Color(red: 0.91, green: 0.68, blue: 0.48)
        case .amber:
            Color(red: 0.92, green: 0.61, blue: 0.29)
        case .rose:
            Color(red: 0.89, green: 0.65, blue: 0.52)
        }
    }

    var accentForeground: Color {
        switch self {
        case .violet, .graphite:
            .white
        case .sage, .ocean, .amber, .rose:
            .black.opacity(0.82)
        }
    }

    var darkPaper: NSColor {
        switch self {
        case .sage: NSColor(red: 0.085, green: 0.11, blue: 0.095, alpha: 1)
        case .ocean: NSColor(red: 0.075, green: 0.095, blue: 0.12, alpha: 1)
        case .violet: NSColor(red: 0.095, green: 0.082, blue: 0.12, alpha: 1)
        case .amber: NSColor(red: 0.12, green: 0.095, blue: 0.07, alpha: 1)
        case .rose: NSColor(red: 0.12, green: 0.082, blue: 0.09, alpha: 1)
        case .graphite: NSColor(red: 0.085, green: 0.09, blue: 0.095, alpha: 1)
        }
    }

    var darkCard: NSColor {
        switch self {
        case .sage: NSColor(red: 0.12, green: 0.15, blue: 0.13, alpha: 1)
        case .ocean: NSColor(red: 0.105, green: 0.13, blue: 0.16, alpha: 1)
        case .violet: NSColor(red: 0.13, green: 0.11, blue: 0.16, alpha: 1)
        case .amber: NSColor(red: 0.16, green: 0.13, blue: 0.095, alpha: 1)
        case .rose: NSColor(red: 0.16, green: 0.11, blue: 0.12, alpha: 1)
        case .graphite: NSColor(red: 0.125, green: 0.135, blue: 0.14, alpha: 1)
        }
    }

    var lightPaper: NSColor {
        switch self {
        case .sage: NSColor(red: 0.965, green: 0.965, blue: 0.935, alpha: 1)
        case .ocean: NSColor(red: 0.945, green: 0.965, blue: 0.978, alpha: 1)
        case .violet: NSColor(red: 0.965, green: 0.95, blue: 0.978, alpha: 1)
        case .amber: NSColor(red: 0.985, green: 0.965, blue: 0.925, alpha: 1)
        case .rose: NSColor(red: 0.985, green: 0.95, blue: 0.95, alpha: 1)
        case .graphite: NSColor(red: 0.96, green: 0.962, blue: 0.958, alpha: 1)
        }
    }

    var lightCard: NSColor {
        switch self {
        case .sage: NSColor(red: 0.99, green: 0.99, blue: 0.97, alpha: 1)
        case .ocean: NSColor(red: 0.975, green: 0.988, blue: 0.996, alpha: 1)
        case .violet: NSColor(red: 0.99, green: 0.98, blue: 0.998, alpha: 1)
        case .amber: NSColor(red: 1, green: 0.988, blue: 0.96, alpha: 1)
        case .rose: NSColor(red: 1, green: 0.978, blue: 0.98, alpha: 1)
        case .graphite: NSColor(red: 0.985, green: 0.987, blue: 0.985, alpha: 1)
        }
    }
}

enum MossTheme {
    static var current: MossColorTheme {
        MossColorTheme(rawValue: UserDefaults.standard.string(forKey: "colorTheme") ?? "") ?? .sage
    }

    static var sage: Color { current.accent }
    static var sageDeep: Color { current.accentDeep }
    static var mint: Color { current.completion }
    static var apricot: Color { current.warm }
    static let brick = Color(red: 0.68, green: 0.36, blue: 0.31)
    static var hairline: Color { Color.primary.opacity(0.09) }
    static var quietFill: Color { Color.primary.opacity(0.035) }
    static var elevatedShadow: Color { Color.black.opacity(0.08) }
    static var paper: Color { Color(nsColor: NSColor(name: nil) { appearance in
        let theme = current
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? theme.darkPaper
            : theme.lightPaper
    }) }
    static var card: Color { Color(nsColor: NSColor(name: nil) { appearance in
        let theme = current
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? theme.darkCard
            : theme.lightCard
    }) }
    static let textSecondary = Color.secondary.opacity(0.82)
}

enum MossSurfaceKind {
    case standard
    case quiet
    case hero
}

struct MossCard<Content: View>: View {
    var padding: CGFloat = 20
    var kind: MossSurfaceKind = .standard
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(fillStyle)
                    .shadow(
                        color: kind == .hero ? MossTheme.elevatedShadow : .clear,
                        radius: kind == .hero ? 22 : 0,
                        y: kind == .hero ? 12 : 0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var fillStyle: AnyShapeStyle {
        switch kind {
        case .standard:
            AnyShapeStyle(MossTheme.card.opacity(0.90))
        case .quiet:
            AnyShapeStyle(MossTheme.quietFill)
        case .hero:
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        MossTheme.card,
                        MossTheme.sage.opacity(0.10),
                        MossTheme.card.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var borderColor: Color {
        switch kind {
        case .standard: MossTheme.hairline
        case .quiet: MossTheme.hairline.opacity(0.65)
        case .hero: MossTheme.sage.opacity(0.18)
        }
    }
}

struct MossPageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                if !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(MossTypography.font(10, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(MossTheme.sage)
                }
                Text(title)
                    .font(MossTypography.editorial(31, weight: .semibold))
                    .tracking(-0.5)
                Text(subtitle)
                    .font(MossTypography.font(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            trailing
        }
        .accessibilityElement(children: .contain)
    }
}

extension MossPageHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct MossMetric: View {
    let value: String
    let label: String
    var symbol: String?
    var tint: Color = MossTheme.sage

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(MossTypography.font(16, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(MossTypography.font(10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)，\(value)")
    }
}

struct CapsuleButtonStyle: ButtonStyle {
    var tint: Color = MossTheme.sage
    var prominent = false
    var prominentForeground: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MossTypography.font(13, weight: .semibold))
            .foregroundStyle(prominent ? (prominentForeground ?? MossTheme.current.accentForeground) : tint)
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(prominent ? tint : tint.opacity(configuration.isPressed ? 0.18 : 0.11))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func mossMonospacedDigits() -> some View {
        fontDesign(.rounded).monospacedDigit()
    }
}

extension TimeInterval {
    var clockString: String {
        let value = max(0, Int(self.rounded()))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    var compactDuration: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var chineseDuration: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) 小时 \(minutes) 分" }
        if hours > 0 { return "\(hours) 小时" }
        return "\(minutes) 分钟"
    }
}

extension Date {
    var dayStart: Date { Calendar.current.startOfDay(for: self) }
}
