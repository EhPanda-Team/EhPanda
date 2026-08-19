import AppComponents
import AppModels

extension AppError {
    /// The toast a refused or failed download action renders (WR-04, WR-05, DEF-15-05).
    ///
    /// **Three action families share it, which is why it is named for none of them.** The inspector's
    /// `retryPagesDone` and `toggleDownloadPauseDone`, and the list's `toggleDownloadPauseDone`, all
    /// answer a tap the download client refused, and the user's question is the same one on all
    /// three: the screen did not move, why. The mapping is therefore stated over `AppError` as a
    /// whole rather than over the kinds one caller happens to raise, and it lives in its own file
    /// rather than inside one consumer, so a fourth family can adopt it without re-deriving
    /// anything.
    ///
    /// **`.fileOperationFailed` is rendered by its payload alone, deliberately.** That is the kind
    /// `retryPages` uses to carry a sentence naming which of its refusals happened — the pages you
    /// selected are not this gallery's — and `alertText` would prefix its own generic "local file
    /// operation failed" line ahead of that specific one, burying the part that answers the user's
    /// question. Every other kind keeps `alertText`, which is the app's own wording for it: an
    /// absent gallery is genuinely `.notFound`, and saying so is the whole reason the inadmissible
    /// selection stopped being `.notFound` too. `togglePause` raises no file-shaped refusal today —
    /// its only exits are `.notFound` and `.unknown`, so it reaches the fallback on both — but the
    /// payload arm is the contract it inherits, and a pause case pins it against this rename.
    ///
    /// `alertText` is empty for two kinds that carry no user-facing sentence (`.noUpdates`,
    /// `.webImageFailed`); neither is reachable from any of the three routes, but a toast whose
    /// message is blank reports nothing, which is the defect this mapping exists to close.
    /// `localizedDescription` has a case for every kind and is never empty, so the fallback cannot
    /// degenerate.
    var actionFailureToast: AppAlertState<Never> {
        if case .fileOperationFailed(let message) = self, !message.isEmpty {
            return .error(caption: message)
        }
        return .error(caption: alertText.isEmpty ? localizedDescription : alertText)
    }
}
