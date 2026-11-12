import AppModels
import Foundation
import Kanna
import ParserFeature

extension Request {
    /// HTML lists expose only the site's chosen title. Load both variants once for the page,
    /// retaining HTML ordering, vote-strength tags and list-specific fields. A missing API entry
    /// leaves its HTML row intact; a failed request remains a visible, retryable request failure.
    func galleriesWithTitles(
        doc: any HTMLDocument,
        host: GalleryHost,
        in session: URLSession
    ) async throws -> [Gallery] {
        let galleries = try parseResponse(doc: doc, Parser.parseGalleries)
        let metadata = try await GalleriesMetadataRequest(
            host: host,
            gidList: galleries.map({ (gid: $0.gid, token: $0.token) }),
            urlSession: session
        ).response()
        let titles = Dictionary(metadata.map({ ($0.id, $0) }), uniquingKeysWith: { first, _ in first })
        return galleries.map { gallery in
            guard let source = titles[gallery.id] else { return gallery }
            var result = gallery
            result.title = source.title
            result.jpnTitle = source.jpnTitle
            return result
        }
    }
}
