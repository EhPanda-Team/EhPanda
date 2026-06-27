import Foundation

public struct TagDetail: Equatable, Sendable {
    public init(
        title: String,
        description: String,
        imageURLs: [URL],
        links: [URL]
    ) {
        self.title = title
        self.description = description
        self.imageURLs = imageURLs
        self.links = links
    }
    public let title: String
    public let description: String
    public let imageURLs: [URL]
    public let links: [URL]
}
