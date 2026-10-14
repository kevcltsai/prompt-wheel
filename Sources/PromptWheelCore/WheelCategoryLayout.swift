import Foundation

/// Production geometry for the category buttons drawn around the wheel.
public struct WheelCategorySlot: Equatable, Sendable {
    public let index: Int
    public let isMore: Bool
    public let center: CGPoint
    public let labelWidth: CGFloat
    public let buttonHeight: CGFloat

    public func containsCapsuleHitPoint(_ point: CGPoint) -> Bool {
        let radius = buttonHeight / 2
        let capsuleStart = center.x - labelWidth / 2 + radius
        let capsuleEnd = center.x + labelWidth / 2 - radius
        let nearestX = min(max(point.x, capsuleStart), capsuleEnd)
        let dx = point.x - nearestX
        let dy = point.y - center.y
        return dx * dx + dy * dy <= radius * radius
    }
}

public enum WheelCategoryLayout {
    public static func slots(size: CGFloat, categoryCount: Int) -> [WheelCategorySlot] {
        let visibleCount = min(13, max(0, categoryCount))
        let hasOverflow = categoryCount > visibleCount
        let itemCount = visibleCount + (hasOverflow ? 1 : 0)
        guard itemCount > 0 else { return [] }

        let outerCount = min(7, itemCount)
        let innerCount = max(0, itemCount - outerCount)
        let buttonHeight = min(32, max(19, size * 0.115))
        let center = CGPoint(x: size / 2, y: size / 2)

        return (0..<itemCount).map { index in
            let isOuter = index < outerCount
            let localIndex = isOuter ? index : index - outerCount
            let ringCount = isOuter ? outerCount : innerCount
            let radius = size * (innerCount > 0 ? (isOuter ? 0.38 : 0.245) : 0.36)
            let circumferenceWidth = 2 * Double.pi * Double(radius) / Double(max(ringCount, 1))
            let labelWidth = CGFloat(max(34, min(68, circumferenceWidth - 8)))
            let angle = -Double.pi / 2 + 2 * Double.pi * Double(localIndex) / Double(max(ringCount, 1))
            let point = CGPoint(x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius)
            return WheelCategorySlot(index: index,
                isMore: hasOverflow && index == visibleCount,
                center: point, labelWidth: labelWidth, buttonHeight: buttonHeight)
        }
    }
}
