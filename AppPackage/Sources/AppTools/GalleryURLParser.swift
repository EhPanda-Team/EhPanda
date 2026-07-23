import Foundation

public enum GalleryURLParser {
    public struct Route: Equatable, Sendable {
        public let url: URL
        public let gid: String
        public let pageIndex: Int?
        public let commentID: String?
        public let isGalleryImageURL: Bool

        public init(
            url: URL,
            gid: String,
            pageIndex: Int?,
            commentID: String?,
            isGalleryImageURL: Bool
        ) {
            self.url = url
            self.gid = gid
            self.pageIndex = pageIndex
            self.commentID = commentID
            self.isGalleryImageURL = isGalleryImageURL
        }
    }

    public static func parse(_ url: URL) -> Route? {
        guard let url = normalizedURL(from: url),
              let host = url.host()?.lowercased(),
              recognizedHosts.contains(host)
        else { return nil }

        var components = url.pathComponents.dropFirst().makeIterator()
        guard let kind = components.next(),
              let routeValue = components.next(),
              let token = components.next(),
              token.isEmpty == false
        else { return nil }

        let gid: String
        let pageIndex: Int?
        let isSinglePageRoute: Bool
        switch kind {
        case "g":
            gid = routeValue
            pageIndex = nil
            isSinglePageRoute = false

        case "s":
            var tokenComponents = token
                .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
                .makeIterator()
            guard let gidComponent = tokenComponents.next(),
                  let pageComponent = tokenComponents.next()
            else { return nil }
            gid = String(gidComponent)
            pageIndex = Int(pageComponent)
            isSinglePageRoute = true

        default:
            return nil
        }

        guard gid.isEmpty == false,
              gid.allSatisfy({ ("0"..."9").contains($0) })
        else { return nil }

        let commentID: String?
        if let fragment = url.fragment, fragment.first == "c", fragment.count > 1 {
            commentID = String(fragment.dropFirst())
        } else {
            commentID = nil
        }
        return Route(
            url: url,
            gid: gid,
            pageIndex: pageIndex,
            commentID: commentID,
            isGalleryImageURL: isSinglePageRoute && commentID == nil
        )
    }

    public static func isMPVURL(_ url: URL?) -> Bool {
        url?.pathComponents.dropFirst().first == "mpv"
    }

    private static let recognizedHosts: Set<String> = {
        [Defaults.URL.ehentai, Defaults.URL.exhentai]
            .compactMap({ $0.host()?.lowercased() })
            .reduce(into: Set<String>()) { hosts, host in
                hosts.insert(host)
                hosts.insert("www.\(host)")
            }
    }()

    private static func normalizedURL(from url: URL) -> URL? {
        switch url.scheme?.lowercased() {
        case "ehpanda":
            return url.replaceScheme(to: "https")

        case "https":
            return url

        default:
            return nil
        }
    }
}
