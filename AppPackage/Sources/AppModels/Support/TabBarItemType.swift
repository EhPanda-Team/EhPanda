public enum TabBarItemType: Int, CaseIterable, Identifiable, Sendable {
    public var id: Int { rawValue }

    case home
    case library
    case search
    case setting
}

public enum LibraryGroup: Hashable, Sendable {
    case favorites(Int)
    case downloads(DownloadFolderFilter)
}
