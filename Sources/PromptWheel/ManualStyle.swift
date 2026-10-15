import AppKit
import SwiftUI
import PromptWheelCore

/// The reference-manual world: section hues at full strength, a milk-acetate leaf,
/// near-black ink, and vermilion reserved for errata.
enum Manual {
    struct Hue {
        let board: Color
        let ink: Color
    }

    static let ink = Color(red: 0.082, green: 0.082, blue: 0.082)              // #151515
    static let inkSoft = Color(red: 0.29, green: 0.275, blue: 0.247)          // #4A463F
    static let acetate = Color(red: 0.957, green: 0.949, blue: 0.925)         // #F4F2EC
    static let vermilion = Color(red: 0.851, green: 0.22, blue: 0.118)        // #D9381E
    static let paperRule = Color(red: 0.082, green: 0.082, blue: 0.082).opacity(0.12)

    /// Oxide orange, chrome yellow, grass, teal, ultramarine, violet, sienna.
    /// Ink on each board is chosen for at least 4.5:1 contrast.
    static let hues: [Hue] = [
        Hue(board: Color(red: 0.886, green: 0.416, blue: 0.173), ink: ink),          // #E26A2C
        Hue(board: Color(red: 0.949, green: 0.761, blue: 0.188), ink: ink),          // #F2C230
        Hue(board: Color(red: 0.357, green: 0.659, blue: 0.271), ink: ink),          // #5BA845
        Hue(board: Color(red: 0.075, green: 0.651, blue: 0.639), ink: ink),          // #13A6A3
        Hue(board: Color(red: 0.184, green: 0.310, blue: 0.710), ink: .white),       // #2F4FB5
        Hue(board: Color(red: 0.463, green: 0.314, blue: 0.690), ink: .white),       // #7650B0
        Hue(board: Color(red: 0.604, green: 0.306, blue: 0.173), ink: .white)        // #9A4E2C
    ]

    static func hue(at index: Int) -> Hue { hues[SectionIndex.hueIndex(forCategoryAt: index)] }

    /// Barlow Condensed (OFL, bundled in Resources/Fonts) stands in for the
    /// manual's Univers Condensed lettering.
    static func head(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let face: String
        switch weight {
        case .bold, .heavy, .black: face = "BarlowCondensed-Bold"
        case .semibold: face = "BarlowCondensed-SemiBold"
        default: face = "BarlowCondensed-Medium"
        }
        return .custom(face, fixedSize: size)
    }
    /// Songti TC sets Han text and its full-width punctuation without the gaps the
    /// system serif's CJK fallback adds; its Latin is a book serif in the Sabon role.
    static func body(_ size: CGFloat) -> Font { .custom("Songti TC", fixedSize: size + 1) }
    static func machine(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Changes in this world are steps, not tweens: sections swap in place.
    static let step: Animation? = nil
}

/// A section's divider tab. The open tab stands at full size and reaches across the
/// gap into its board; the others step back.
struct SectionTab: View {
    let name: String
    let count: Int
    let number: Int?
    let hue: Manual.Hue
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool
    let hovered: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scale: CGFloat { isActive ? 1 : (hovered ? 0.95 : 0.86) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // The number slot is always reserved so labels align past nine sections.
                Text(number.map(String.init) ?? " ").font(Manual.machine(9.5, weight: .medium))
                    .frame(width: 9, alignment: .leading)
                Text(name)
                    .font(Manual.head(height < 36 ? 15 : 17, weight: isActive ? .bold : .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text("\(count)").font(Manual.machine(10, weight: .medium))
                    .padding(.trailing, isActive ? SectionIndex.activeOverlap : 0)
            }
            .foregroundStyle(hue.ink)
            .padding(.leading, 10).padding(.trailing, 9)
            .frame(width: width, height: height, alignment: .leading)
            .background(hue.board, in: UnevenRoundedRectangle(
                topLeadingRadius: 2, bottomLeadingRadius: 2,
                bottomTrailingRadius: isActive ? 0 : 7, topTrailingRadius: isActive ? 0 : 7))
            .brightness(hovered && !isActive ? 0.04 : 0)
            .shadow(color: .black.opacity(isActive ? 0 : 0.16), radius: 1.5, x: 1, y: 1)
            .contentShape(Rectangle())
            // Visual only: layout stays put, so neighbouring tabs never shift under the pointer.
            .scaleEffect(scale, anchor: .leading)
            .animation(reduceMotion ? nil : .spring(response: 0.16, dampingFraction: 0.85), value: scale)
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .help("\(name)：\(count) 個 prompts")
        .accessibilityLabel("\(name)，\(count) 個 prompts")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Milk acetate: opaque so it reads the same milk over every board, with a lit
/// top edge and a soft contact shadow instead of a hard offset.
struct AcetateLeaf: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Manual.acetate)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.15)],
                               startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1.5)
    }
}

/// The leaf's state line when something needs attention.
struct ErrataSlip: View {
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("ERRATA").font(Manual.machine(9.5, weight: .bold))
                .padding(.horizontal, 4).padding(.vertical, 1)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(0.8), lineWidth: 1))
            Text(text).font(.system(size: 12.5, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(Manual.head(15, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Manual.vermilion, in: RoundedRectangle(cornerRadius: 2))
        .accessibilityElement(children: .combine)
    }
}

/// Two punched holes on the leaf's bound edge, showing the board through them.
struct PunchHoles: View {
    let color: Color
    var body: some View {
        VStack {
            hole
            Spacer()
            hole
        }
        .padding(.vertical, 34)
        .accessibilityHidden(true)
    }
    private var hole: some View { PunchedHole(color: color, diameter: 12) }
}

/// A hole punched through the acetate: the board shows through, with a shaded
/// rim on the upper edge and a lit lip on the lower one.
struct PunchedHole: View {
    let color: Color
    let diameter: CGFloat
    var body: some View {
        Circle().fill(color)
            .overlay(Circle().strokeBorder(
                LinearGradient(colors: [.black.opacity(0.42), .black.opacity(0.08)],
                               startPoint: .top, endPoint: .bottom), lineWidth: 1.4))
            .overlay(Circle().inset(by: 1.4).trim(from: 0.05, to: 0.45)
                .stroke(.white.opacity(0.55), lineWidth: 0.8))
            .frame(width: diameter, height: diameter)
    }
}

/// SwiftUI hosting view that accepts the first click. The picker panel never
/// activates Prompt Wheel, so without this a click can be spent focusing the window.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
