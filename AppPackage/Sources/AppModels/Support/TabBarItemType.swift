public enum TabBarItemType: Int, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case home
    case favorites
    case search
    case downloads
    case setting
}
