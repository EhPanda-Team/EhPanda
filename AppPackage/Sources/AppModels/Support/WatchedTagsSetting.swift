import Foundation
import SwiftUI
import AppTools
import Synchronization

final class TagLookupCache: Sendable {
    private let cache: Mutex<[String: (tagSetBackgroundColor: Color?, tag: WatchedTag)]>

    init() {
        cache = Mutex([:])
    }

    var isEmpty: Bool {
        cache.withLock { $0.isEmpty }
    }

    var allEntries: [String: (tagSetBackgroundColor: Color?, tag: WatchedTag)] {
        cache.withLock { $0 }
    }

    func update(_ newCache: [String: (tagSetBackgroundColor: Color?, tag: WatchedTag)]) {
        cache.withLock { $0 = newCache }
    }

    func removeAll() {
        cache.withLock { $0.removeAll() }
    }
}

public actor WatchedTagsSetting {
    public static let shared = WatchedTagsSetting()

    private var onlineTags: [Int: TagSetInfo] = [:]
    private var lastFetchedApuid: String = ""
    private var lastRefreshTimestamp: Date = .distantPast
    private let lookupCache = TagLookupCache()

    private init() {}

    public func updateTagSet(_ tagSet: TagSetInfo, apiuid: String) {
        onlineTags[tagSet.number] = tagSet
        lastFetchedApuid = apiuid
        lastRefreshTimestamp = Date()
        rebuildLookupCache()
    }

    public func updateTagSet(_ tagSet: TagSetInfo) {
        onlineTags[tagSet.number] = tagSet
        rebuildLookupCache()
    }

    private func rebuildLookupCache() {
        var lookup: [String: (Color?, WatchedTag)] = [:]
        for tagSetInfo in onlineTags.values {
            for tag in tagSetInfo.tags {
                let key = "\(tag.namespace):\(tag.key)"
                lookup[key] = (tagSetInfo.backgroundColor, tag)
            }
        }
        lookupCache.update(lookup)
    }

    public func buildTagLookup() -> [String: (tagSetBackgroundColor: Color?, tag: WatchedTag)] {
        if !lookupCache.isEmpty { return lookupCache.allEntries }
        var lookup: [String: (Color?, WatchedTag)] = [:]
        for tagSetInfo in onlineTags.values {
            for tag in tagSetInfo.tags {
                let key = "\(tag.namespace):\(tag.key)"
                lookup[key] = (tagSetInfo.backgroundColor, tag)
            }
        }
        lookupCache.update(lookup)
        return lookup
    }

    public nonisolated var cachedTagLookup: [String: (tagSetBackgroundColor: Color?, tag: WatchedTag)] {
        lookupCache.allEntries
    }

    public func clearOnlineTagSets() {
        onlineTags.removeAll()
        lookupCache.removeAll()
        lastFetchedApuid = ""
        lastRefreshTimestamp = .distantPast
    }

    public func needsRefresh(apiuid: String, maxAge: TimeInterval = 3600) -> Bool {
        return onlineTags.isEmpty || lastFetchedApuid != apiuid || isStale(maxAge: maxAge)
    }

    public func isStale(maxAge: TimeInterval = 3600) -> Bool {
        return Date().timeIntervalSince(lastRefreshTimestamp) > maxAge
    }

    public func allTagSets() -> [TagSetInfo] {
        Array(onlineTags.values).sorted { $0.number < $1.number }
    }

    public static func applyWatchedTagColors(to tags: [GalleryTag]) -> [GalleryTag] {
        let lookup = shared.cachedTagLookup
        var recolored = tags
        for tagIndex in recolored.indices {
            var tag = recolored[tagIndex]
            var contents = tag.contents
            for contentIndex in contents.indices {
                var content = contents[contentIndex]
                if content.textColor != nil || content.backgroundColor != nil {
                    contents[contentIndex] = content
                    continue
                }
                let lookupKey = "\(content.rawNamespace):\(content.text)"
                if let result = lookup[lookupKey] {
                    let backgroundColor = result.tag.backgroundColor ?? result.tagSetBackgroundColor
                    content.backgroundColor = backgroundColor ?? Color(hex: "3377FF")
                    let resolvedBackground = content.backgroundColor
                    content.textColor = backgroundColor == nil
                        ? Color(hex: "F1F1F1")
                        : (resolvedBackground?.isLightColor ?? false
                            ? Color(red: 0.035, green: 0.035, blue: 0.035)
                            : Color(hex: "F1F1F1"))
                }
                contents[contentIndex] = content
            }
            tag.contents = contents
            recolored[tagIndex] = tag
        }
        return recolored
    }
}
