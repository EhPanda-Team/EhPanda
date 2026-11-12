public import Foundation

extension URL {
    private static let ignoredStableCacheQueryNames: Set<String> = [
        "dl", "download", "source", "from", "view"
    ]
    private static let preferredStableCacheQueryNames: Set<String> = [
        "gid", "page", "imgkey", "fileindex", "xres", "p", "key"
    ]

    /// The primary cache key: host- and query-independent, and independent of the per-request
    /// signature a served page image carries in its path.
    ///
    /// An E-Hentai page image is served from
    /// `/h/<hash>-<bytes>-<w>-<h>-<ext>/keystamp=<expiry>-<mac>;fileindex=<n>;xres=<r>/<name>`.
    /// `keystamp` is a time-limited signature that rotates every few minutes, so keeping it made
    /// every visit to the same page look like a new image. It is dropped here; the content hash,
    /// `fileindex` and `xres` still identify the image and its resolution.
    public var stableImageCacheKey: String? {
        makeStableImageCacheKey(dropsSignature: true)
    }

    /// The key 3.0 wrote reader-cache entries under: the whole path, signature included. Kept so
    /// those entries stay readable (and evictable) until they age out; equal to
    /// ``stableImageCacheKey`` whenever the path carries no signature.
    public var legacyStableImageCacheKey: String? {
        makeStableImageCacheKey(dropsSignature: false)
    }

    private func makeStableImageCacheKey(dropsSignature: Bool) -> String? {
        let normalizedPath = pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
            .compactMap({ dropsSignature ? Self.removingSignatureItems(from: $0) : $0 })
            .joined(separator: "/")
        guard !normalizedPath.isEmpty else { return nil }

        let queryItems = normalizedStableCacheQueryItems
        guard !queryItems.isEmpty else {
            return "download::\(normalizedPath)"
        }

        let normalizedQuery = queryItems
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        return "download::\(normalizedPath)?\(normalizedQuery)"
    }

    /// Removes the `keystamp=…` item from a `;`-separated path component; nil when nothing else is left.
    private static func removingSignatureItems(from component: String) -> String? {
        guard component.contains(";") || component.lowercased().hasPrefix("keystamp=") else {
            return component
        }
        let kept = component
            .split(separator: ";", omittingEmptySubsequences: true)
            .filter { !$0.lowercased().hasPrefix("keystamp=") }
        return kept.isEmpty ? nil : kept.joined(separator: ";")
    }

    /// The keys an image is cached under, primary first: the stable alias (when the
    /// path yields one) so differing query/host/signature variants of the same page
    /// collide, then the legacy alias that 3.0 wrote entries under (only when it differs),
    /// then the absolute URL as an exact-match fallback. Writers store under the primary
    /// key; readers check them in order.
    public var imageCacheKeys: [String] {
        var keys = [String]()
        if let stableImageCacheKey {
            keys.append(stableImageCacheKey)
        }
        if let legacyStableImageCacheKey, !keys.contains(legacyStableImageCacheKey) {
            keys.append(legacyStableImageCacheKey)
        }
        keys.append(absoluteString)
        return keys
    }

    private var normalizedStableCacheQueryItems: [URLQueryItem] {
        guard let components = URLComponents(
            url: self,
            resolvingAgainstBaseURL: false
        ),
            let queryItems = components.queryItems?
                .filter({ !($0.value ?? "").isEmpty })
        else {
            return []
        }

        let preferredQueryItems = queryItems.filter {
            Self.preferredStableCacheQueryNames.contains($0.name.lowercased())
        }
        let filteredQueryItems = preferredQueryItems.isEmpty
            ? queryItems.filter {
                !Self.ignoredStableCacheQueryNames
                    .contains($0.name.lowercased())
            }
            : preferredQueryItems

        return filteredQueryItems.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return (lhs.value ?? "") < (rhs.value ?? "")
            }
            return lhs.name < rhs.name
        }
    }
}
