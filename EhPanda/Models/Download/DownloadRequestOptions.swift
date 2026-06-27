/// Execution policy for a download: *how* to fetch (thread limit, cellular, auto-retry),
/// not *what* to fetch. Deliberately separate from `DownloadRequestPayload` and never
/// persisted to a manifest or request: it is resolved fresh from the latest settings once
/// per run (see `downloadOptionsProvider`) and threaded to the workers, so a settings change
/// while a gallery sits queued takes effect when it finally starts.
struct DownloadRequestOptions: Equatable, Sendable {
    var threadLimit = Setting.downloadThreadLimitDefaultValue
    var allowCellular = Setting.downloadAllowCellularDefaultValue
    var autoRetryFailedPages = Setting.downloadAutoRetryFailedPagesDefaultValue

    var workerCount: Int {
        threadLimit
    }
}
