import Foundation

// The browsing-history list persisted behind `@Shared(.galleryHistory)`. Kept most-recent-first;
// these are the only mutators, so the ordering and per-gid uniqueness invariants live here rather
// than being re-derived at each call site. None of them trim — the 1,000-entry cap is enforced
// solely by a launch-time prune, so in-session upserts may temporarily grow the list past the cap.
extension Array where Element == GalleryHistoryEntry {
    /// The saved resume page for `gid`, or 0 when the gallery has no history entry yet.
    public func readingProgress(gid: String) -> Int {
        first { $0.gid == gid }?.readingProgress ?? 0
    }

    /// Records that `gid` was just opened: stamps its recency with `date`, moves it to the front,
    /// fills in a previously-missing token, and preserves any saved reading progress. Inserts a
    /// fresh entry when the gallery is new to the history.
    public mutating func recordGalleryOpen(gid: String, token: String, date: Date) {
        var entry = first { $0.gid == gid } ?? GalleryHistoryEntry(gid: gid, token: token, lastOpenDate: date)
        removeAll { $0.gid == gid }
        entry.lastOpenDate = date
        if entry.token.isEmpty { entry.token = token }
        insert(entry, at: 0)
    }

    /// Updates the saved resume page for `gid` in place, leaving its recency and position untouched.
    /// Inserts a fresh front entry stamped `date` when the gallery has no history yet — e.g. a deep
    /// link that jumps straight to a page before the detail screen records the open (that later open
    /// backfills the token via `recordGalleryOpen`).
    public mutating func updateReadingProgress(gid: String, token: String, progress: Int, date: Date) {
        if let index = firstIndex(where: { $0.gid == gid }) {
            self[index].readingProgress = progress
        } else {
            insert(
                GalleryHistoryEntry(gid: gid, token: token, lastOpenDate: date, readingProgress: progress),
                at: 0
            )
        }
    }

    /// Trims the list to the `historyCap` most-recent entries by `lastOpenDate`. Called only at
    /// launch: it also normalises the order to most-recent-first when it has to drop anything.
    public mutating func pruneToHistoryCap() {
        guard count > GalleryHistoryEntry.historyCap else { return }
        self = Array(
            sorted { $0.lastOpenDate > $1.lastOpenDate }.prefix(GalleryHistoryEntry.historyCap)
        )
    }
}
