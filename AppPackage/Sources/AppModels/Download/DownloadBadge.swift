public struct DownloadBadge: Equatable, Sendable {
    public init(
        status: DownloadDisplayStatus,
        progress: DownloadProgress
    ) {
        self.status = status
        self.progress = progress
    }
    public let status: DownloadDisplayStatus
    public let progress: DownloadProgress
}
