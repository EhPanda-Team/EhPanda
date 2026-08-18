import AppModels
import Foundation

/// The single owner of one run's log cursor AND of the run file the cursor names — fetch, append
/// and cursor-advance are one serialized step, performed by whoever holds this actor.
///
/// **The contract.** `drain(into:)` returns exactly the entries the file now holds that it did not
/// hold before: nothing is returned that was not written, and nothing is written whose cursor did
/// not advance. Those two clauses are what make an entry reach the file exactly once however many
/// callers tick concurrently.
///
/// **The absence of `await` inside `drain(into:)` IS the atomicity.** An actor method with no
/// suspension point runs to completion before any other call can enter, so the fetch cannot read a
/// cursor that a concurrent append is about to move, and no interleaving can append the same batch
/// twice. That is why `Fetch` and `Append` are synchronous throwing closures rather than `async`
/// ones: an `async` seam here would reopen the very window this type exists to close, and would do
/// it silently. Anything added to the body must stay synchronous for the same reason.
///
/// The split ownership it replaces is worth recording, because the shape looks harmless: the pump
/// held the cursor in reducer state, advanced it through an action `send`, and appended to disk
/// afterwards. `Send` is a no-op once its effect is cancelled, so a cancelled tick could append
/// without advancing; and two effects started from one stale cursor snapshot each fetched — and
/// each wrote — the same batch. The device's jsonl showed both, as lines repeated three times.
public actor RunLogDrain {
    /// Reads the entries emitted since `after` (or since boot when `after` is `nil`), oldest first.
    public typealias Fetch = @Sendable (_ after: Date?) throws -> [AppActivityLog]
    /// Appends entries to the run file at `url`, creating it when needed.
    public typealias Append = @Sendable (_ logs: [AppActivityLog], _ url: URL) throws -> Void

    private let fetch: Fetch
    private let append: Append
    /// The date of the last entry this drain has written. The ONLY writer is the success path of
    /// `drain(into:)`, three lines after the append it belongs to.
    private var cursor: Date?

    public init(
        fetch: @escaping Fetch,
        append: @escaping Append
    ) {
        self.fetch = fetch
        self.append = append
    }

    /// Fetches everything after the cursor, appends it to `url`, advances the cursor, and returns
    /// what was written. Returns no entries when there was nothing to write, or when the tick
    /// could not honor the contract above.
    public func drain(into url: URL) -> [AppActivityLog] {
        let entries: [AppActivityLog]
        do {
            entries = try fetch(cursor)
        } catch {
            // A transient OS-log read failure intentionally yields nothing this tick. The cursor is
            // untouched, so the next tick asks the same question over the same window.
            return []
        }
        guard let lastDate = entries.last?.date else { return [] }
        do {
            try append(entries, url)
        } catch {
            // Persisting diagnostic logs is best-effort and never interrupts the live pump. The
            // cursor is deliberately left where it was, so these entries are re-offered next tick
            // rather than silently skipped.
            //
            // Deliberately silent, carrying the reason from the pump this replaced: it reads back
            // the app's own OSLog, so logging a failure here would emit an entry that the next tick
            // fetches and re-attempts to persist — a self-feeding loop for as long as the
            // persistent condition (e.g. a full disk) lasts.
            return []
        }
        cursor = lastDate
        return entries
    }
}
