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

struct MossCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MossTheme.card.opacity(0.96))
                    .shadow(color: .black.opacity(0.045), radius: 14, y: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

struct CapsuleButtonStyle: ButtonStyle {
    var tint: Color = MossTheme.sage
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : tint)
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
