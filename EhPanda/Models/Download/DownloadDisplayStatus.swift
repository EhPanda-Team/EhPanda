enum DownloadDisplayStatus: Equatable, CaseIterable, Sendable {
    case active
    case queued
    case updateAvailable
    case error
    case inactive
    case completed
}

extension DownloadDisplayStatus {
    var sortPriority: Int {
        switch self {
        case .active:
            return 0
        case .queued:
            return 1
        case .updateAvailable:
            return 2
        case .error:
            return 3
        case .inactive:
            return 4
        case .completed:
            return 5
        }
    }
}
