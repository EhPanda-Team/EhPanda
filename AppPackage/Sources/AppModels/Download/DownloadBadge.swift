public struct DownloadBadge: Equatable, Sendable {
    public init(
        status: DownloadDisplayStatus,
        progress: DownloadProgress,
        waitingPosition: Int? = nil
    ) {
        self.status = status
        self.progress = progress
        self.waitingPosition = waitingPosition
    }
    public let status: DownloadDisplayStatus
    public let progress: DownloadProgress
    /// The waiting item's place among the waiting downloads (1 starts next) while `status` is `.queued`, nil
    /// otherwise. VoiceOver speaks it; nothing draws it (B-6).
    public let waitingPosition: Int?
}
