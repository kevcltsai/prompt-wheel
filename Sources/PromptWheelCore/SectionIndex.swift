import Foundation

/// Geometry and colour assignment for the picker's divider-tab rail.
/// Pure values so layout decisions are testable without AppKit.
public enum SectionIndex {
    /// Fixed panel size. The panel never resizes while it is open, so nothing
    /// moves under the pointer between mouse-down and mouse-up.
    public static let panelSize = CGSize(width: 700, height: 440)
    public static let railWidth: CGFloat = 168
    public static let tabGap: CGFloat = 4
    public static let railInset: CGFloat = 16
    public static let minTabHeight: CGFloat = 30
    public static let maxTabHeight: CGFloat = 46
    /// How far the open tab reaches past the rail to join its board.
    public static let activeOverlap: CGFloat = 10
    /// Room around the board for its shadow inside the transparent panel.
    public static let boardInset: CGFloat = 14

    /// Number of section hues; category `i` uses hue `i % hueCount`.
    public static let hueCount = 7

    public static func hueIndex(forCategoryAt index: Int) -> Int {
        ((index % hueCount) + hueCount) % hueCount
    }

    /// Tab height so every category fits the rail; below the minimum the rail scrolls.
    public static func tabHeight(categoryCount: Int) -> CGFloat {
        guard categoryCount > 0 else { return maxTabHeight }
        let available = panelSize.height - railInset * 2 - tabGap * CGFloat(categoryCount - 1)
        return min(maxTabHeight, max(minTabHeight, (available / CGFloat(categoryCount)).rounded(.down)))
    }

    public static func railScrolls(categoryCount: Int) -> Bool {
        guard categoryCount > 0 else { return false }
        let needed = CGFloat(categoryCount) * minTabHeight + tabGap * CGFloat(categoryCount - 1)
        return needed > panelSize.height - railInset * 2
    }

    /// Where to reopen a picker the user moved: the saved origin, kept fully visible,
    /// but only when it is on the screen the pointer is on. Otherwise nil, so the
    /// picker opens at the pointer as usual.
    public static func restoredOrigin(saved: CGPoint?, pointer: CGPoint, visibleFrames: [CGRect],
                                      margin: CGFloat = 10) -> CGPoint? {
        guard let saved,
              let screen = visibleFrames.first(where: { $0.contains(pointer) }) else { return nil }
        let center = CGPoint(x: saved.x + panelSize.width / 2, y: saved.y + panelSize.height / 2)
        guard screen.contains(center) else { return nil }
        let bounds = screen.insetBy(dx: margin, dy: margin)
        return CGPoint(x: min(max(saved.x, bounds.minX), max(bounds.minX, bounds.maxX - panelSize.width)),
                       y: min(max(saved.y, bounds.minY), max(bounds.minY, bounds.maxY - panelSize.height)))
    }

    /// Screen origin (AppKit, bottom-left) that puts the first tab under the
    /// pointer, then keeps the whole panel inside the visible frame.
    public static func origin(pointer: CGPoint, visibleFrame: CGRect, margin: CGFloat = 10) -> CGPoint {
        let firstTabCenterFromTopLeft = CGPoint(x: railWidth * 0.5, y: railInset + minTabHeight * 0.5)
        let proposed = CGPoint(x: pointer.x - firstTabCenterFromTopLeft.x,
                               y: pointer.y + firstTabCenterFromTopLeft.y - panelSize.height)
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let maxX = max(bounds.minX, bounds.maxX - panelSize.width)
        let maxY = max(bounds.minY, bounds.maxY - panelSize.height)
        return CGPoint(x: min(max(proposed.x, bounds.minX), maxX),
                       y: min(max(proposed.y, bounds.minY), maxY))
    }
}
