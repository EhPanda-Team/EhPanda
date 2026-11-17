import Foundation

// MARK: - A user deletion leaves the continued session
extension DownloadCoordinator {
    /// **B-1 (261117-tyj, owner decision): a gallery the user deletes leaves the continued session
    /// entirely.** Its pages leave both X and Y and it stops counting toward N, whatever state it
    /// was in: active, queued, paused, or completed earlier in the session. This removes the
    /// gallery's ledger entry and its last observation, and gives what they held back to the
    /// numerator's monotonic floor, so the card counts exactly the galleries the session still
    /// covers and later real work is not absorbed by a floor that still counted pages the user
    /// removed. The owner accepts that the numerator may step back once, here.
    ///
    /// **Why the deletion boundary classifies the reason, not the reconcile.** Every other departure
    /// (completion, pause, the queued-work-item cancel, the expiration pause-all, a record dropped
    /// at a scan boundary) retires the gallery's finished pages into both sides of the fraction
    /// (D-G2-01), and `reconcileRetiredSessionPages` deliberately takes no reason. Only this code
    /// knows the gallery left because the user deleted it, so the rule lives here and the reconcile
    /// stays free of departure-reason branches. D-G7-01's bracket cannot do it either: it reads a
    /// vanished gallery as no movement, because a departure is valued once by the reconcile.
    ///
    /// **What the session counts for the gallery is "ledger entry, else last observation".** The two
    /// entries are mutually exclusive by the reconcile's construction: a reconcile drops the ledger
    /// entry of every gallery it observes live, and observation is replaced wholesale. So the sum of
    /// what the two removals return is exactly what the session currently counts for the gallery,
    /// and, for a gallery whose record is gone, exactly what the next reconcile would have retired.
    /// Both entries are always removed, so nothing of the gallery survives into a later push.
    ///
    /// **It runs synchronously with the record removal.** Both callers invoke it on the line after
    /// `downloadIndex[gid] = nil`, so no push can observe a record-less gallery that is still
    /// observed. A push that ran earlier, during the deletion's own awaits (its scheduling block
    /// hides the gallery, so that push retires it), is answered by the ledger branch. A push whose
    /// client hop straddles this call may repaint the pre-deletion frame once, and the deletion's own
    /// convergence push (`notifyObservers` and `scheduleNextIfNeeded` follow) repaints the truth.
    ///
    /// **The client-start hop is closed.** `ensureContinuedSession` seeds its state before the
    /// client start's main-actor hop, so a deletion landing inside the hop finds the observation to
    /// withdraw, and nothing re-seeds the gallery from a stale snapshot afterwards.
    ///
    /// **The floor can be over-withdrawn only inertly.** It may hold less than what is withdrawn (for
    /// example run-exit freeze progress that was not yet pushed). It then sits below the honest
    /// numerator, which the push's `max` makes inert, exactly like the D-G7-01 withdrawal, so the
    /// subtraction is unclamped. The floor can never hold MORE than the withdrawn value for this
    /// gallery, so it never under-withdraws, which would be the defect: the floor would absorb later
    /// work and the scheduler would read the card as stalled.
    ///
    /// **`observedIncompleteSessionGenerations` is deliberately not cleared.** A gallery deleted and
    /// then enqueued again under the same gid is a queue-mobilizing entrance, which advances the
    /// queue-intent generation (CR-02), so the predecessor's stamp cannot credit the successor, and
    /// a per-path clear is what CR-02 records as not wanted. The successor is observed fresh by the
    /// next snapshot and counts only its own work.
    ///
    /// **This is a floor writer owned by the census** (`DownloadSourceInventoryTests`), and it must
    /// stay outside any D-G7-01 bracket: none of its callers opens one, and a withdrawal inside a
    /// bracket would be subtracted twice.
    ///
    /// Called by `delete(gid:)`'s success path and by `deleteFolder(name:)` for each gallery it
    /// removes (B-2: deleting a whole folder is a user deletion too). It is NOT called by
    /// `delete(gid:)`'s not-found and failed-removal branches: this call removed no record there,
    /// and a record that vanished otherwise stays a departure the reconcile values (external folder
    /// mutations are not chased). It touches no file, no index record, no queue, no run basis.
    func withdrawDeletedGalleryFromSession(gid: String) {
        guard continuedSessionID != nil else { return }
        let retiredPages = retiredSessionPages.removeValue(forKey: gid) ?? 0
        let observedPages = observedSchedulablePages.removeValue(forKey: gid) ?? 0
        lastPushedCompletedPageCount -= retiredPages + observedPages
    }
}
