import Foundation

/// Screen-space helpers for dragging the floating wheel panel.
public enum WheelPanelGeometry {
    /// SwiftUI drag translations have a top-left origin; AppKit window coordinates grow upward.
    public static func translatedOrigin(from origin: CGPoint, by translation: CGSize) -> CGPoint {
        CGPoint(x: origin.x + translation.width, y: origin.y - translation.height)
    }

    /// Keep the complete panel within the visible screen area when it fits.
    public static func clampedOrigin(proposed: CGPoint,
                                     panelSize: CGSize,
                                     visibleFrame: CGRect,
                                     margin: CGFloat = 10) -> CGPoint {
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let maxX = max(bounds.minX, bounds.maxX - panelSize.width)
        let maxY = max(bounds.minY, bounds.maxY - panelSize.height)
        return CGPoint(x: min(max(proposed.x, bounds.minX), maxX),
                       y: min(max(proposed.y, bounds.minY), maxY))
    }
}
