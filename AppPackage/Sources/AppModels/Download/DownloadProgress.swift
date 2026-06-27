public struct DownloadProgress: Equatable, Sendable {
    public init(
        completedPageCount: Int,
        pageCount: Int
    ) {
        self.completedPageCount = completedPageCount
        self.pageCount = pageCount
    }
    public let completedPageCount: Int
    public let pageCount: Int

    public var displayPageCount: Int {
        max(pageCount, 1)
    }
    public var displayCompletedPageCount: Int {
        min(max(completedPageCount, 0), displayPageCount)
    }

    public var fraction: Double {
        Double(displayCompletedPageCount) / Double(displayPageCount)
    }
}
