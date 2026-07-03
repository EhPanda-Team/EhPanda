import Resources

public enum DownloadFolderFilter: Equatable, Sendable {
    case all
    case folder(String)

    public var title: String {
        switch self {
        case .all:
            return String(localized: .downloadFolderFilterAll)
        case .folder(let name):
            return name
        }
    }
}

extension DownloadedGallery {
    public func matches(folderFilter: DownloadFolderFilter) -> Bool {
        switch folderFilter {
        case .all:
            return true
        case .folder(let name):
            return folderName == name
        }
    }
}
