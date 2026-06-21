import SwiftUI

enum MossFontTheme: String, CaseIterable, Identifiable {
    case system
    case rounded
    case pingFang
    case songti
    case kaiti
    case avenir
    case serif
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统字体"
        case .rounded: "圆体"
        case .pingFang: "苹方"
        case .songti: "宋体"
        case .kaiti: "楷体"
        case .avenir: "Avenir"
        case .serif: "衬线体"
        case .monospaced: "等宽体"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:
            .system(size: size, weight: weight)
        case .rounded:
            .system(size: size, weight: weight, design: .rounded)
        case .pingFang:
            .custom("PingFang SC", size: size).weight(weight)
        case .songti:
            .custom("Songti SC", size: size).weight(weight)
        case .kaiti:
            .custom("Kaiti SC", size: size).weight(weight)
        case .avenir:
            .custom("Avenir Next", size: size).weight(weight)
        case .serif:
            .system(size: size, weight: weight, design: .serif)
        case .monospaced:
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

enum MossFontSize: String, CaseIterable, Identifiable {
    case compact
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "紧凑"
        case .standard: "标准"
        case .large: "较大"
        case .extraLarge: "特大"
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact: 0.90
        case .standard: 1
        case .large: 1.12
        case .extraLarge: 1.25
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .compact: .small
        case .standard: .medium
        case .large: .large
        case .extraLarge: .xLarge
        }
    }
}

enum MossTypography {
    static var theme: MossFontTheme {
        MossFontTheme(rawValue: UserDefaults.standard.string(forKey: "fontTheme") ?? "") ?? .rounded
    }

    static var size: MossFontSize {
        MossFontSize(rawValue: UserDefaults.standard.string(forKey: "fontSize") ?? "") ?? .standard
    }

    static func font(_ baseSize: CGFloat, weight: Font.Weight = .regular) -> Font {
        theme.font(size: baseSize * size.scale, weight: weight)
    }
}

private struct MossTypographyModifier: ViewModifier {
    @AppStorage("fontTheme") private var fontTheme = MossFontTheme.rounded.rawValue
    @AppStorage("fontSize") private var fontSize = MossFontSize.standard.rawValue

    func body(content: Content) -> some View {
        let theme = MossFontTheme(rawValue: fontTheme) ?? .rounded
        let size = MossFontSize(rawValue: fontSize) ?? .standard
        content
            .font(theme.font(size: 13 * size.scale))
            .dynamicTypeSize(size.dynamicTypeSize)
            .id("\(fontTheme)-\(fontSize)")
    }
}

extension View {
    func mossTypography() -> some View {
        modifier(MossTypographyModifier())
    }
}
