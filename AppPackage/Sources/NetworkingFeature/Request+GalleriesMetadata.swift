import AppModels
import Combine
import Foundation
import AppTools

// MARK: Response types
private struct GalleriesMetadataAPIResponse: Decodable {
    let gmetadata: [GalleryMetadata]
}

/// One `gmetadata` entry from the `gdata` API. Every display field is optional because the API
/// returns a bare `{ gid, error }` object for gids it can't resolve (expunged/removed galleries);
/// `gallery` yields `nil` for those so a single bad entry never fails the whole batch.
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

    var gallery: Gallery? {
        guard error == nil,
              let token,
              let title,
              let posted, let postedInterval = TimeInterval(posted)
        else { return nil }
        return Gallery(
            gid: String(gid),
            token: token,
            title: title.htmlEntitiesDecoded,
            rating: rating.flatMap(Float.init) ?? 0,
            tags: Self.parseTags(tags ?? []),
            category: category.flatMap(AppModels.Category.init(rawValue:)) ?? .misc,
            uploader: uploader,
            pageCount: filecount.flatMap(Int.init) ?? 0,
            postedDate: Date(timeIntervalSince1970: postedInterval),
            coverURL: thumb.flatMap { URL(string: $0) },
            galleryURL: Defaults.URL.host
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
public struct GalleriesMetadataRequest: Request {
    public let gidList: [(gid: String, token: String)]
    public let urlSession: URLSession

    public init(gidList: [(gid: String, token: String)], urlSession: URLSession = .shared) {
        self.gidList = gidList
        self.urlSession = urlSession
    }

    public var publisher: AnyPublisher<[Gallery], AppError> {
        let order = gidList.map(\.gid)
        let chunks = gidList.chunked(into: 25)
        guard !chunks.isEmpty else {
            return Just([]).setFailureType(to: AppError.self).eraseToAnyPublisher()
        }
        // Cap in-flight POSTs at 2 so a large gid list can't fire an unbounded burst against the
        // flood-controlled `api.php`. Result order is reconstructed from `order` below, so chunk
        // completion order is irrelevant.
        return Publishers.Sequence(sequence: chunks)
            .flatMap(maxPublishers: .max(2)) { chunkPublisher($0) }
            .collect()
            .map { pages in
                let byGID = Dictionary(
                    pages.flatMap { $0 }.map { ($0.gid, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                return order.compactMap { byGID[$0] }
            }
            .eraseToAnyPublisher()
    }

    private func chunkPublisher(_ chunk: [(gid: String, token: String)]) -> AnyPublisher<[Gallery], AppError> {
        let gidlist = chunk.compactMap { pair -> [Any]? in
            guard let gid = Int(pair.gid) else { return nil }
            return [gid, pair.token]
        }
        guard !gidlist.isEmpty else {
            return Just([]).setFailureType(to: AppError.self).eraseToAnyPublisher()
        }

        let params: [String: Any] = [
            "method": "gdata",
            "gidlist": gidlist,
            "namespace": 1
        ]
        var request = URLRequest(url: Defaults.URL.api)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])

        return urlSession.dataTaskPublisher(for: request)
            .genericRetry()
            .map(\.data)
            .tryMap { data in
                try parseResponse(data: data) { try Self.galleries(fromResponseData: $0) }
            }
            .mapError(mapAppError)
            .eraseToAnyPublisher()
    }

    /// Decodes a raw `gdata` payload into galleries, silently dropping every unresolvable
    /// `{ gid, error }` (or tokenless) entry. `token` is optional precisely so one such entry can't
    /// fail `JSONDecoder` for the whole array — a single bad gid must never blank the History batch.
    /// Exposed at `internal` access so tests can assert that per-entry tolerance directly.
    static func galleries(fromResponseData data: Data) throws -> [Gallery] {
        try JSONDecoder().decode(GalleriesMetadataAPIResponse.self, from: data).gmetadata.compactMap(\.gallery)
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
    /// Decodes numeric character references (`&#123;` / `&#x1F;`) and the core XML named entities
    /// found in `gdata` titles. `&amp;` is resolved last so an already-decoded `&` isn't re-read.
    var htmlEntitiesDecoded: String {
        decodingCharacterReferences()
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private func decodingCharacterReferences() -> String {
        var output = ""
        var remainder = Substring(self)
        while let start = remainder.range(of: "&#") {
            output += remainder[remainder.startIndex..<start.lowerBound]
            let afterAmp = start.upperBound
            let isHex = remainder[afterAmp...].first == "x" || remainder[afterAmp...].first == "X"
            let digitsStart = isHex ? remainder.index(after: afterAmp) : afterAmp
            guard let semicolon = remainder[digitsStart...].firstIndex(of: ";") else {
                output += remainder[start.lowerBound...]
                return output
            }
            let digits = remainder[digitsStart..<semicolon]
            if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                output.unicodeScalars.append(scalar)
            } else {
                output += remainder[start.lowerBound...semicolon]
            }
            remainder = remainder[remainder.index(after: semicolon)...]
        }
        output += remainder
        return output
    }
}
