import CoreGraphics
import Foundation

enum IslandPanelPresentation: Equatable {
    case idle
    case compact
    case expanded
}

struct IslandScreenGeometry: Equatable {
    var frame: CGRect
    var visibleFrame: CGRect
    var safeAreaTop: CGFloat
    var displayID: String?

    var hasNotch: Bool {
        safeAreaTop > 0
    }
}

enum IslandPanelGeometry {
    static let panelHeight: CGFloat = 74
    static let cornerMargin: CGFloat = 10

    static func size(
        for presentation: IslandPanelPresentation,
        hasNotch: Bool,
        placement: IslandPlacement
    ) -> CGSize {
        let width: CGFloat
        switch presentation {
        case .idle:
            width = 190
        case .compact:
            width = hasNotch && placement == .topCenter ? 520 : 390
        case .expanded:
            width = hasNotch && placement == .topCenter ? 520 : 500
        }
        return CGSize(width: width, height: panelHeight)
    }

    static func anchorOrigin(
        placement: IslandPlacement,
        screen: IslandScreenGeometry,
        size: CGSize
    ) -> CGPoint {
        let hasNotch = screen.hasNotch && placement == .topCenter
        let bounds = placement == .topCenter ? screen.frame : screen.visibleFrame

        switch placement {
        case .topCenter:
            return CGPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.maxY - size.height - (hasNotch ? 1 : 7)
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
        offset: CGSize
    ) -> CGRect {
        let anchor = anchorOrigin(placement: placement, screen: screen, size: size)
        let proposed = CGRect(
            origin: CGPoint(x: anchor.x + offset.width, y: anchor.y + offset.height),
            size: size
        )
        return clamped(proposed, to: movementBounds(for: placement, screen: screen))
    }

    static func offset(
        for frame: CGRect,
        placement: IslandPlacement,
        screen: IslandScreenGeometry
    ) -> CGSize {
        let anchor = anchorOrigin(placement: placement, screen: screen, size: frame.size)
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
        screen: IslandScreenGeometry
    ) -> CGRect {
        placement == .topCenter ? screen.frame : screen.visibleFrame
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
