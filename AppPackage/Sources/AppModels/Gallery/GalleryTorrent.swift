import Foundation

public struct GalleryTorrent: Identifiable, Codable, Equatable, Sendable {
    public init(
        id: UUID = .init(),
        postedDate: Date,
        fileSize: String,
        seedCount: Int,
        peerCount: Int,
        downloadCount: Int,
        uploader: String,
        fileName: String,
        hash: String,
        torrentURL: URL
    ) {
        self.id = id
        self.postedDate = postedDate
        self.fileSize = fileSize
        self.seedCount = seedCount
        self.peerCount = peerCount
        self.downloadCount = downloadCount
        self.uploader = uploader
        self.fileName = fileName
        self.hash = hash
        self.torrentURL = torrentURL
    }
    public var id: UUID = .init()
    public let postedDate: Date
    public let fileSize: String
    public let seedCount: Int
    public let peerCount: Int
    public let downloadCount: Int
    public let uploader: String
    public let fileName: String
    public let hash: String
    public let torrentURL: URL
}

extension GalleryTorrent: DateFormattable {
    public var originalDate: Date {
        postedDate
    }
    public var magnetURL: String {
        "magnet:?xt=urn:btih:\(hash)"
    }
}
