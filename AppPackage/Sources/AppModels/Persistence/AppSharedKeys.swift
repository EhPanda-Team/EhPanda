import Foundation
import Sharing

// MARK: - Persisted app data (@Shared)
//
// EhPanda is a thin browsing client: it parses and delivers website content and deliberately
// keeps no database. Only light, *bounded* app data is persisted, and it is persisted whole —
// each model as a single Codable value in UserDefaults via Sharing's `appStorage` strategy.
//
// Why whole structs in app storage rather than a database or per-field keys:
//   • Every value here is either capped (`galleryHistory`, `historyKeywords`, `quickSearchWords`)
//     or inherently small (`setting`, `user`, the filters), so the defaults domain comfortably
//     holds it.
//   • Keeping the structs intact preserves their invariants (e.g. `Setting`/`Filter` `didSet`
//     cascades) and makes resets/logout a single atomic assignment.
//   • Forward migration rides on each model's tolerant `init(from:)` decoder (`decodeIfPresent`
//     + defaults): additive changes never invalidate an existing persisted value, and a decode
//     failure falls back to the key's default — there is no store-fails-to-open failure mode.
//
// The one exception is the tag-translation table (`tagTranslator`): it is multi-megabyte, far too
// large for the UserDefaults domain, so it uses the `fileStorage` strategy (a JSON file) instead.
// Everything else fits app storage. Web images keep their own caches. `appStorage` keys must not
// contain `.` or `@`.

// MARK: Account & preferences

extension SharedKey where Self == AppStorageKey<Setting>.Default {
    public static var setting: Self {
        Self[.appStorage("setting"), default: Setting()]
    }
}

extension SharedKey where Self == AppStorageKey<User>.Default {
    public static var user: Self {
        Self[.appStorage("user"), default: User()]
    }
}

// MARK: Filters

extension SharedKey where Self == AppStorageKey<Filter>.Default {
    public static var searchFilter: Self {
        Self[.appStorage("searchFilter"), default: Filter()]
    }
    public static var globalFilter: Self {
        Self[.appStorage("globalFilter"), default: Filter()]
    }
    public static var watchedFilter: Self {
        Self[.appStorage("watchedFilter"), default: Filter()]
    }
}

// MARK: Search history & presets

extension SharedKey where Self == AppStorageKey<[String]>.Default {
    public static var historyKeywords: Self {
        Self[.appStorage("historyKeywords"), default: []]
    }
}

extension SharedKey where Self == AppStorageKey<[QuickSearchWord]>.Default {
    public static var quickSearchWords: Self {
        Self[.appStorage("quickSearchWords"), default: []]
    }
}

// MARK: Tag translations (large — file-backed rather than in the defaults domain)

extension SharedKey where Self == FileStorageKey<TagTranslator>.Default {
    public static var tagTranslator: Self {
        Self[
            .fileStorage(.applicationSupportDirectory.appending(component: "tagTranslator.json")),
            default: TagTranslator()
        ]
    }
}

// MARK: Browsing history (merged recency + reading progress; capped, pruned at launch)

extension SharedKey where Self == AppStorageKey<[GalleryHistoryEntry]>.Default {
    public static var galleryHistory: Self {
        Self[.appStorage("galleryHistory"), default: []]
    }
}
