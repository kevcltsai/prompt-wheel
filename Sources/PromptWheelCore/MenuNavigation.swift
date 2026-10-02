/// Tracks only selection and Return's lifecycle; AppKit owns event delivery.
public struct MenuNavigation {
    public private(set) var selectedIndex = 0
    private var returnArmed = false

    public init() {}

    public mutating func reset() {
        selectedIndex = 0
        returnArmed = false
    }

    public mutating func move(by offset: Int, count: Int) {
        guard count > 0 else { selectedIndex = 0; return }
        selectedIndex = min(max(selectedIndex + offset, 0), count - 1)
    }

    public mutating func returnDown(isRepeat: Bool) {
        if !isRepeat { returnArmed = true }
    }

    public mutating func returnUp(count: Int) -> Int? {
        defer { returnArmed = false }
        return returnArmed && count > 0 ? selectedIndex : nil
    }
}
