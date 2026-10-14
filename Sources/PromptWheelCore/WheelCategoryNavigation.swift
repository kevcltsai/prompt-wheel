/// Routes category hover and activation to the matching in-panel prompt submenu.
public struct WheelCategoryNavigation: Sendable {
    public private(set) var activeCategoryName: String?
    public private(set) var submenuPresented = false

    public init() {}

    @discardableResult
    public mutating func open(categoryName: String,
                              in categories: [PromptCategory]) -> PromptCategory? {
        guard let category = categories.first(where: { $0.name == categoryName }) else { return nil }
        activeCategoryName = category.name
        submenuPresented = true
        return category
    }

    public mutating func collapseSubmenu() {
        submenuPresented = false
    }

    public mutating func reset(activeCategoryName: String? = nil) {
        self.activeCategoryName = activeCategoryName
        submenuPresented = false
    }
}
