import Foundation

/// The identity record for a downloaded gallery, written to `manifest.json` in its folder.
/// Identity lives *here* (`gid` / `token`), not in the folder path: the human-readable
/// `[gid_token] Title` folder name is presentation, and the title in it can change and
/// re-slot the directory without affecting identity. Folder membership follows the file's
/// location on disk, so this manifest is what re-establishes identity after the gallery is
/// moved or renamed via the Files app.
public struct DownloadManifest: Codable, Equatable, Sendable {
    public let gid: String
    public let host: GalleryHost
    public let token: String
    public let title: String
    public let jpnTitle: String?
    public let category: Category
    public let language: Language
    public let remoteCoverURL: URL?
    public let uploader: String?
    public let tags: [GalleryTag]
    public let postedDate: Date
    public let rating: Float
    public var pages: [Int: String]

    public init(
        gid: String,
        host: GalleryHost,
        token: String,
        title: String,
        jpnTitle: String?,
        category: Category,
        language: Language,
        remoteCoverURL: URL?,
        uploader: String?,
        tags: [GalleryTag],
        postedDate: Date,
        rating: Float,
        pages: [Int: String]
    ) {
        self.gid = gid
        self.host = host
        self.token = token
        self.title = title
        self.jpnTitle = jpnTitle
        self.category = category
        self.language = language
        self.remoteCoverURL = remoteCoverURL
        self.uploader = uploader
        self.tags = tags
        self.postedDate = postedDate
        self.rating = rating
        self.pages = pages
    }
}

extension DownloadManifest {
    public var pageCount: Int {
        pages.count
    }

    public var galleryURL: URL {
        host.url
            .appendingPathComponent("g")
            .appendingPathComponent(gid)
            .appendingPathComponent(token)
    }

    public var completedPageCount: Int {
        pages.values.filter { !$0.isEmpty }.count
    }

    public var isComplete: Bool {
        !pages.isEmpty && completedPageCount == pages.count
    }
}
