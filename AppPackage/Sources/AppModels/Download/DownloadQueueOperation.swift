/// A change to where a gallery waits in the download queue (B-2). `isApplicable(status:place:)` is the predicate the
/// downloads menu, its VoiceOver actions and the coordinator all read, so an item that is hidden and a request that
/// is refused cannot disagree (B-5).
public enum DownloadQueueOperation: String, CaseIterable, Sendable {
    case downloadNow
    case downloadNext
    case moveUp
    case moveDown
    case downloadLast

    /// Whether the operation applies to a gallery with this display status and waiting place. Download Now applies
    /// to any waiting item, with or without a known place, and to a paused item (`.inactive`). Download Next applies
    /// to a paused item (`.inactive`) and to a waiting item that is not already next (position above 1); Move Up
    /// to a waiting item that is not first; Move Down and Download Last to a waiting item that is not last
    /// (position below the waiting count). No other status offers any, and a waiting item without a known place
    /// offers no position-dependent operation.
    public func isApplicable(status: DownloadDisplayStatus, place: DownloadQueuePlace?) -> Bool {
        switch self {
        case .downloadNow:
            return status == .queued || status == .inactive
        case .downloadNext:
            switch status {
            case .inactive:
                return true
            case .queued:
                return (place?.position ?? 0) > 1
            case .active, .updateAvailable, .error, .completed:
                return false
            }
        case .moveUp:
            return status == .queued && (place?.position ?? 0) > 1
        case .moveDown, .downloadLast:
            guard status == .queued, let place else { return false }
            return place.position < place.waitingCount
        }
    }
}
