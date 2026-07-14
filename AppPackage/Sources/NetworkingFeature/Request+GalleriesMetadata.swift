import AppModels
import Foundation
import AppTools

// MARK: Response types
private struct GalleriesMetadataAPIResponse: Decodable {
    let gmetadata: [GalleryMetadata]
}

/// One `gmetadata` entry from the `gdata` API. Every display field is optional because the API
/// returns a bare `{ gid, error }` object for gids it can't resolve (expunged/removed galleries);
/// `gallery` yields `nil` for those so a single bad entry never fails the whole batch. A *resolved*
/// entry still missing any field the display needs (token, title, posted, category, rating, cover,
/// pageCount) is likewise dropped rather than defaulted, mirroring the HTML list parser's
/// all-or-nothing row policy.
private struct GalleryMetadata: Decodable {
    let gid: Int
    let token: String?
    let error: String?
    let title: String?
    let category: String?
    let thumb: String?
    let uploader: String?
    let posted: String?
    let filecount: String?
    let rating: String?
    let tags: [String]?

    func gallery(host: GalleryHost) -> Gallery? {
        // Match the HTML list parser: a resolved row needs its full display set, or it is dropped.
        // Only `tags` and `uploader` stay tolerant.
        guard error == nil,
              let token,
              let title,
              let posted, let postedInterval = TimeInterval(posted),
              let category = category.flatMap(AppModels.Category.init(rawValue:)),
              let rating = rating.flatMap(Float.init),
              let coverURL = thumb.flatMap({ URL(string: $0) }),
              let pageCount = filecount.flatMap(Int.init)
        else { return nil }
        return Gallery(
            gid: String(gid),
            token: token,
            title: title.htmlEntitiesDecoded,
            rating: rating,
            tags: Self.parseTags(tags ?? []),
            category: category,
            uploader: uploader,
            pageCount: pageCount,
            postedDate: Date(timeIntervalSince1970: postedInterval),
            coverURL: coverURL,
            galleryURL: host.url
                .appendingPathComponent("g")
                .appendingPathComponent(String(gid))
                .appendingPathComponent(token)
        )
    }

    /// Groups the flat `"namespace:content"` tag list (returned because the request sets
    /// `namespace: 1`) into `GalleryTag`s. A tag without a namespace falls under `misc`.
    private static func parseTags(_ raw: [String]) -> [GalleryTag] {
        var tags = [GalleryTag]()
        for entry in raw {
            let parts = entry.split(separator: ":", maxSplits: 1).map(String.init)
            let namespace = parts.count == 2 ? parts[0] : "misc"
            let text = parts.count == 2 ? parts[1] : entry
            let content = GalleryTag.Content(
                rawNamespace: namespace, text: text, isVotedUp: false, isVotedDown: false
            )
            if let index = tags.firstIndex(where: { $0.rawNamespace == namespace }) {
                tags[index] = .init(rawNamespace: namespace, contents: tags[index].contents + [content])
            } else {
                tags.append(.init(rawNamespace: namespace, contents: [content]))
            }
        }
        return tags
    }
}

// MARK: Request
/// Resolves display metadata for a set of galleries via the `gdata` API. The app persists no
/// gallery snapshots, so the History screen and "recently seen" suggestions rebuild their cells
/// from this on demand. The `gdata` endpoint accepts at most 25 gid/token pairs per call, so the
/// input is chunked and the chunks are fetched concurrently, then reassembled in input order
/// (unresolved gids are dropped).
public struct GalleriesMetadataRequest: Request, Sendable {
    public let host: GalleryHost
    public let gidList: [(gid: String, token: String)]
    public let urlSession: URLSession

    public init(
        host: GalleryHost,
        gidList: [(gid: String, token: String)],
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.gidList = gidList
        self.urlSession = urlSession
    }

    public func response() async throws(AppError) -> [Gallery] {
        let order = gidList.map(\.gid)
        let chunks = gidList.chunked(into: 25)
        guard !chunks.isEmpty else {
            return []
        }

        let pages = try await fetchChunks(chunks)
        let byGID = Dictionary(
            pages.flatMap { $0 }.map { ($0.gid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return order.compactMap { byGID[$0] }
    }

    private func fetchChunks(
        _ chunks: [[(gid: String, token: String)]]
    ) async throws(AppError) -> [[Gallery]] {
        let result = await withTaskGroup(
            of: Result<[Gallery], AppError>.self,
            returning: Result<[[Gallery]], AppError>.self
        ) { group in
            var nextIndex = 0
            for chunk in chunks.prefix(2) {
                group.addTask {
                    await self.chunkResult(chunk)
                }
                nextIndex += 1
            }

            var pages = [[Gallery]]()
            while let result = await group.next() {
                switch result {
                case .success(let galleries):
                    pages.append(galleries)
                    if nextIndex < chunks.count {
                        let chunk = chunks[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            await self.chunkResult(chunk)
                        }
                    }
                case .failure(let error):
                    group.cancelAll()
                    return .failure(error)
                }
            }
            return .success(pages)
        }
        return try result.get()
    }

    private func chunkResult(
        _ chunk: [(gid: String, token: String)]
    ) async -> Result<[Gallery], AppError> {
        let gidlist = chunk.compactMap { pair -> [Any]? in
            guard let gid = Int(pair.gid) else { return nil }
            return [gid, pair.token]
        }
        guard !gidlist.isEmpty else {
            return .success([])
        }
        do throws(AppError) {
            return .success(
                try await gdataResponse(host: host, gidlist: gidlist, urlSession: urlSession) {
                    try Self.galleries(fromResponseData: $0, host: host)
                }
            )
        } catch {
            return .failure(error)
        }
    }

    /// Decodes a raw `gdata` payload into galleries, silently dropping every unresolvable
    /// `{ gid, error }` (or tokenless) entry. `token` is optional precisely so one such entry can't
    /// fail `JSONDecoder` for the whole array — a single bad gid must never blank the History batch.
    /// Exposed at `internal` access so tests can assert that per-entry tolerance directly.
    static func galleries(fromResponseData data: Data, host: GalleryHost) throws -> [Gallery] {
        try JSONDecoder()
            .decode(GalleriesMetadataAPIResponse.self, from: data)
            .gmetadata
            .compactMap { $0.gallery(host: host) }
    }
}

// MARK: Helpers
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

private extension String {
    /// Decodes numeric character references (`&#123;` / `&#x1F;`) and the core XML named entities in
    /// `gdata` titles in a single left-to-right pass, so a decoded substitution is never rescanned: an
    /// escaped literal `&lt;` written as `&#38;lt;` decodes once to `&lt;`, not to `<`. (A two-stage
    /// numeric-then-named decode broke that invariant.)
    var htmlEntitiesDecoded: String {
        replacing(/&(?:#(\d+)|#[xX]([0-9a-fA-F]+)|(amp|lt|gt|quot|apos));/) { match in
            if let decimal = match.1, let code = UInt32(decimal), let scalar = Unicode.Scalar(code) {
                return String(scalar)
            }
            if let hex = match.2, let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                return String(scalar)
            }
            switch match.3.map(String.init) {
            case "amp": return "&"
            case "lt": return "<"
            case "gt": return ">"
            case "quot": return "\""
            case "apos": return "'"
            default: return String(match.0)
            }
        }
    }
}
