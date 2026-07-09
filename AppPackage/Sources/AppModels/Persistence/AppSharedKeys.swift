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
//   • Models decode *strictly* (synthesized Codable, or a hand-written throwing decoder where an
//     identity invariant must hold). A corrupt or shape-incompatible blob fails to decode and
//     Sharing falls back to the key's default — a clean, coherent reset, never a partially-filled
//     Franken-value. Additive evolution stays cheap: a new *optional* field is absent-tolerant
//     automatically under synthesized decode, so old blobs stay valid.
//
// Cap policies differ by the *kind* of data, deliberately:
//   • `galleryHistory` (auto-recorded browsing) is capped at `GalleryHistoryEntry.historyCap` and
//     trimmed only by a launch-time prune, so in-session upserts may briefly exceed the cap.
//   • `historyKeywords` (auto-recorded searches) is capped at write time by evicting the oldest,
//     keeping the most recent 20.
//   • `quickSearchWords` (user-*authored* presets) is capped at `QuickSearchReducer.wordLimit` but is
//     never evicted — the add control is simply disabled at the limit, because silently dropping a
//     saved word would lose user work. Auto-recorded data is disposable; authored data is not.
//
// Every model carries a self-validating `SchemaVersion` field (default 1) that rejects a
// newer/downgrade value on decode and logs the anomaly via OSLog (see `SchemaVersion`), then fails
// the decode so Sharing resets to the key default rather than half-reading an unknown shape. The
// four whole-struct models (`Setting`,
// `User`, the filters, `TagTranslatorInfo`) keep synthesized strict Codable — the typed field gates
// the version without a hand-written decoder, preserving their `didSet` invariants and optional-field
// tolerance. The two identity-bearing array-element models (`GalleryHistoryEntry`, `QuickSearchWord`)
// still hand-write `init(from:)` for their identity invariants, decoding that same `SchemaVersion`
// field for the version check. When a real breaking change lands, the affected model gains or extends
// a custom `init(from:)` that switches on the version to map the older shape forward.
//
// Nothing here uses the `fileStorage` strategy. The tag-translation table is the only large
// artifact, and it is deliberately NOT persisted through Sharing: only its thin
// `tagTranslatorInfo` metadata lives in app storage, while the multi-megabyte translations are a
// plain, re-downloadable cache file rebuilt at launch (see `TagTranslatorInfo`). Web images keep
// their own caches. `appStorage` keys must not contain `.` or `@`.

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

// The daily "New Dawn" greeting is an ephemeral reward, not durable account identity, so it lives in
// memory only and resets to `nil` on the next launch. Two features write it — the Setting daily fetch
// and the Detail-page parse — through the newer-only `mergeNewer(_:)` rule (see `Greeting`).
extension SharedKey where Self == InMemoryKey<Greeting?>.Default {
    public static var greeting: Self {
        Self[.inMemory("greeting"), default: nil]
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

// MARK: Tag translations (thin metadata only — the table itself is a rebuilt cache file)

extension SharedKey where Self == AppStorageKey<TagTranslatorInfo>.Default {
    public static var tagTranslatorInfo: Self {
        Self[.appStorage("tagTranslatorInfo"), default: TagTranslatorInfo()]
    }
}

// The full translation table (multi-megabyte `translations` dictionary) is rebuilt at launch from the
// cache file, so it lives in memory only — never in app storage. `SettingFeature` owns the writes (the
// launch rebuild and language switches); every other feature reads it through `@SharedReader`, so tag
// lookups no longer thread a `TagTranslator` copy down through each view.
extension SharedKey where Self == InMemoryKey<TagTranslator>.Default {
    public static var tagTranslator: Self {
        Self[.inMemory("tagTranslator"), default: TagTranslator()]
    }
}

// MARK: Browsing history (merged recency + reading progress; capped, pruned at launch)

extension SharedKey where Self == AppStorageKey<[GalleryHistoryEntry]>.Default {
    public static var galleryHistory: Self {
        Self[.appStorage("galleryHistory"), default: []]
    }
}
