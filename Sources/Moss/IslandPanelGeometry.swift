import CoreGraphics
import Foundation

enum IslandPanelPresentation: Equatable {
    case idle
    case compact
    case expanded
    case launcher
}

struct IslandScreenGeometry: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
    var safeAreaTop: CGFloat
    var notchWidth: CGFloat = 0
    var displayID: String?

    var hasNotch: Bool {
        safeAreaTop > 0 || notchWidth > 0
    }

    var notchGapWidth: CGFloat {
        max(IslandPanelGeometry.minimumNotchGapWidth, notchWidth + 16)
    }
}

enum IslandPanelGeometry {
    static let cornerMargin: CGFloat = 10
    static let minimumNotchGapWidth: CGFloat = 118
    private static let compactLobesWidth: CGFloat = 402

    static func size(
        for presentation: IslandPanelPresentation,
        hasNotch: Bool,
        placement: IslandPlacement,
        notchGapWidth: CGFloat = minimumNotchGapWidth
    ) -> CGSize {
        switch presentation {
        case .idle:
            return CGSize(width: 530, height: 86)
        case .compact:
            let width = hasNotch && placement == .topCenter
                ? compactLobesWidth + max(minimumNotchGapWidth, notchGapWidth)
                : 390
            return CGSize(width: width, height: 74)
        case .expanded:
            return CGSize(width: 560, height: 120)
        case .launcher:
            return CGSize(width: 530, height: 250)
        }
    }

    static func anchorOrigin(
        placement: IslandPlacement,
        screen: IslandScreenGeometry,
        size: CGSize,
        avoidsNotch: Bool = false
    ) -> CGPoint {
        let integratesWithNotch = screen.hasNotch
            && placement == .topCenter
            && !avoidsNotch
        let bounds = placement == .topCenter && !avoidsNotch
            ? screen.frame
            : screen.visibleFrame

        switch placement {
        case .topCenter:
            return CGPoint(
                x: screen.frame.midX - size.width / 2,
                y: bounds.maxY - size.height - (integratesWithNotch ? 1 : 7)
            )
        case .topLeading:
            return CGPoint(
                x: bounds.minX + cornerMargin,
                y: bounds.maxY - size.height - cornerMargin
            )
        case .topTrailing:
            return CGPoint(
                x: bounds.maxX - size.width - cornerMargin,
                y: bounds.maxY - size.height - cornerMargin
            )
        case .bottomLeading:
            return CGPoint(
                x: bounds.minX + cornerMargin,
                y: bounds.minY + cornerMargin
            )
        case .bottomTrailing:
            return CGPoint(
                x: bounds.maxX - size.width - cornerMargin,
                y: bounds.minY + cornerMargin
            )
        }
    }

    static func frame(
        placement: IslandPlacement,
        screen: IslandScreenGeometry,
        size: CGSize,
        offset: CGSize,
        avoidsNotch: Bool = false
    ) -> CGRect {
        let anchor = anchorOrigin(
            placement: placement,
            screen: screen,
            size: size,
            avoidsNotch: avoidsNotch
        )
        let proposed = CGRect(
            origin: CGPoint(x: anchor.x + offset.width, y: anchor.y + offset.height),
            size: size
        )
        return clamped(
            proposed,
            to: movementBounds(
                for: placement,
                screen: screen,
                avoidsNotch: avoidsNotch
            )
        )
    }

    static func offset(
        for frame: CGRect,
        placement: IslandPlacement,
        screen: IslandScreenGeometry,
        avoidsNotch: Bool = false
    ) -> CGSize {
        let anchor = anchorOrigin(
            placement: placement,
            screen: screen,
            size: frame.size,
            avoidsNotch: avoidsNotch
        )
        return CGSize(width: frame.minX - anchor.x, height: frame.minY - anchor.y)
    }

    static func clamped(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        var origin = frame.origin
        let maxX = max(bounds.minX, bounds.maxX - frame.width)
        let maxY = max(bounds.minY, bounds.maxY - frame.height)
        origin.x = min(max(origin.x, bounds.minX), maxX)
        origin.y = min(max(origin.y, bounds.minY), maxY)
        return CGRect(origin: origin, size: frame.size)
    }

    static func movementBounds(
        for placement: IslandPlacement,
        screen: IslandScreenGeometry,
        avoidsNotch: Bool = false
    ) -> CGRect {
        placement == .topCenter && !avoidsNotch
            ? screen.frame
            : screen.visibleFrame
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
