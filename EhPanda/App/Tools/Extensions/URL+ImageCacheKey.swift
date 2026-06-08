//
//  URL+ImageCacheKey.swift
//  EhPanda
//

import Foundation

extension URL {
    private static let ignoredStableCacheQueryNames: Set<String> = [
        "dl", "download", "source", "from", "view"
    ]
    private static let preferredStableCacheQueryNames: Set<String> = [
        "gid", "page", "imgkey", "fileindex", "xres", "p", "key"
    ]

    var stableImageCacheKey: String? {
        let normalizedPath = pathComponents
            .filter { $0 != "/" && $0.notEmpty }
            .joined(separator: "/")
        guard normalizedPath.notEmpty else { return nil }

        let queryItems = normalizedStableCacheQueryItems
        guard !queryItems.isEmpty else {
            return "download::\(normalizedPath)"
        }

        let normalizedQuery = queryItems
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        return "download::\(normalizedPath)?\(normalizedQuery)"
    }

    func imageCacheKeys(includeStableAlias: Bool) -> [String] {
        var keys = [String]()
        if includeStableAlias, let stableImageCacheKey {
            keys.append(stableImageCacheKey)
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
                .filter({ ($0.value ?? "").notEmpty })
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
