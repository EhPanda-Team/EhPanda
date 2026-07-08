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
// Every model also carries a `schemaVersion` (default 1): a reserved anchor for a future *breaking*
// migration, so a genuinely incompatible change has an explicit version to branch on rather than
// inferring compatibility from the decoded shape. The two array-element models with an identity
// invariant (`GalleryHistoryEntry`, `QuickSearchWord`) decode through hand-written throwing decoders
// that reject an out-of-range `schemaVersion`; the whole-struct models rely on synthesized strict
// decode (a shape mismatch already resets to the key default) and reintroduce a branching decoder
// if and when a breaking change lands.
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

// A reducer that fires a network request needs a *value* copy of the currently-persisted filter to
// capture into its `.run` closure — never the live `@Shared` reference, which would read a later,
// possibly mid-edit value by the time the effect actually runs. These accessors centralize that
// read-and-copy so no call site can accidentally capture the reference.
extension Filter {
    public static var currentSearch: Filter {
        @Shared(.searchFilter) var filter
        return filter
    }
    public static var currentGlobal: Filter {
        @Shared(.globalFilter) var filter
        return filter
    }
    public static var currentWatched: Filter {
        @Shared(.watchedFilter) var filter
        return filter
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

// MARK: Browsing history (merged recency + reading progress; capped, pruned at launch)

extension SharedKey where Self == AppStorageKey<[GalleryHistoryEntry]>.Default {
    public static var galleryHistory: Self {
        Self[.appStorage("galleryHistory"), default: []]
    }
}
