import Foundation
public import Sharing

// MARK: - Persisted app data (@Shared)
//
// EhPanda is a thin browsing client: it parses and delivers website content and deliberately
// keeps no database. Only light, *bounded* app data is persisted, and it is persisted whole —
// each model as a single Codable value in UserDefaults via Sharing's `appStorage` strategy.
//
// Why whole structs in app storage rather than a database or per-field keys:
//   • Every value here is either capped (`galleryHistory`, `historyKeywords`, `savedSearches`)
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
//   • `savedSearches` (user-*authored* presets) is capped at `QuickSearchReducer.savedSearchLimit` but is
//     never evicted — the add control is simply disabled at the limit, because silently dropping a
//     saved search would lose user work. Auto-recorded data is disposable; authored data is not.
//
// Every model carries a self-validating `SchemaVersion` field (default 1) that rejects a
// newer/downgrade value on decode and logs the anomaly via OSLog (see `SchemaVersion`), then fails
// the decode so Sharing resets to the key default rather than half-reading an unknown shape. The
// four whole-struct models (`Setting`,
// `User`, the filters, `TagTranslatorInfo`) keep synthesized strict Codable — the typed field gates
// the version without a hand-written decoder, preserving their `didSet` invariants and optional-field
// tolerance. The two identity-bearing array-element models (`GalleryHistoryEntry`, `SavedSearch`)
// still hand-write `init(from:)` for their identity invariants, decoding that same `SchemaVersion`
// field for the version check. Every model also declares an ordered `schemas` history (à la SwiftData's
// `SchemaMigrationPlan.schemas`), starting at its v1 base schema, from which `currentSchemaVersion` is
// derived. When a real breaking change lands, the model appends a `VersionedSchema` whose `migrate` maps
// the previous shape forward and adopts `MigratableModel`; the `SchemaMigrator` engine then walks the
// chain in order (v1→v2→v3…) during decode. See `VersionedSchema` / `SchemaMigrator`.
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

// The Cloudflare clearance pair earned by a challenge web view (see `CloudflareClearance`). The login
// flow writes it on capture, reads it to proactively attach the cookie and its bound User-Agent to
// later login POSTs in the same session — so an unexpired clearance skips the wall entirely — and
// replaces it whenever a retry comes back challenged again. The in-memory strategy *is* the
// no-persistence guarantee: the pair resets to `nil` on every launch with no cleanup code, and it can
// never reach app storage, a file, or the shared cookie jar.
extension SharedKey where Self == InMemoryKey<CloudflareClearance?>.Default {
    public static var cloudflareClearance: Self {
        Self[.inMemory("cloudflareClearance"), default: nil]
    }
}

/// Transient scene-phase blur written by `AppReducer` and read by `.privacyMask()`, reset to `0` on launch.
extension SharedKey where Self == InMemoryKey<Double>.Default {
    public static var privacyMaskBlur: Self {
        Self[.inMemory("privacyMaskBlur"), default: 0]
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

// MARK: Analytics

extension SharedKey where Self == AppStorageKey<InstallSignalState>.Default {
    /// Whether the one install signal has settled (D-06b). Kept apart from `Setting` on purpose, so a
    /// settings reset never sends the signal again.
    public static var installSignal: Self {
        Self[.appStorage("installSignal"), default: InstallSignalState()]
    }
}

// MARK: Comment moderation

extension SharedKey where Self == AppStorageKey<[BlockedCommentUser]>.Default {
    /// The posters whose comments are collapsed, by E-Hentai member ID, in the order they were blocked (DD-10, D-13;
    /// owner msg 1918). Kept on this device only; edit it through `block(memberID:name:)` and `unblock(memberID:)` so
    /// each ID is held once. The key is new with the member ID: the name-keyed list before it never shipped.
    public static var blockedCommentUsers: Self {
        Self[.appStorage("blockedCommentUsers"), default: []]
    }
}

extension SharedKey where Self == AppStorageKey<[SavedSearch]>.Default {
    /// Stays under the key existing installs already hold.
    public static var savedSearches: Self {
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
