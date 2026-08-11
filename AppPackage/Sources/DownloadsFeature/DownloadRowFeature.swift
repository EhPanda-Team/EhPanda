import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
import Resources

/// One row of the downloads list, owning that row's delete confirmation.
///
/// **Why a child reducer exists for what looks like a single boolean.** The confirmation has to
/// address exactly one row, and a presentation modifier needs a binding that is non-nil for that
/// row alone. A single `@Presents` on ``DownloadsReducer`` cannot supply one: every row would read
/// the same non-nil value and every row would present. Narrowing a shared value to one row means
/// deriving a binding, which the project's `binding_initializer` lint rule forbids. Per-row *state*
/// is the way out — the parent holds these as an `IdentifiedArray` and composes them with
/// `.forEach`, so each row scopes a store whose dialog is its own, and the binding is projected
/// rather than derived.
///
/// The row owns only its presentation and the intent behind it. Update, pause, move, inspect and
/// open stay on the parent: they carry no per-row presentation state, and routing them through a
/// delegate would add a hop without removing anything. Deletion is delegated rather than performed
/// here because the effect belongs to the list — the download client call, its analytics, and the
/// silent-failure policy documented on ``DownloadsReducer`` are all list-level concerns.
@Reducer
public struct DownloadRowFeature: Sendable {
    public enum Delegate: Equatable, Sendable {
        case confirmDelete
    }

    public enum Dialog: Equatable, Sendable {
        case confirmDelete
    }

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var download: DownloadedGallery
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?

        /// The gallery id, so a row survives snapshot replacement with its dialog intact.
        public var id: String { download.id }

        public init(download: DownloadedGallery) {
            self.download = download
        }
    }

    public enum Action {
        case deleteButtonTapped
        case confirmationDialog(PresentationAction<Dialog>)
        case delegate(Delegate)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .deleteButtonTapped:
                // Read out before the builders, which escape and so cannot capture `state`.
                let isRunning = state.download.canTogglePause
                // `.visible` explicitly: the default `.automatic` drops the title whenever a
                // message is present, and the alert this replaced showed both.
                state.confirmationDialog = ConfirmationDialogState(titleVisibility: .visible) {
                    TextState(localized: .RLocalizable.deleteDownload)
                } actions: {
                    // No cancel button: this dialog presents as a popover anchored to its row, and
                    // that presentation omits `.cancel`-role buttons whether they are declared or
                    // left to SwiftUI's automatic one. Dismissal is a tap outside the popover.
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState(localized: .RLocalizable.delete)
                    }
                } message: {
                    TextState(
                        localized: isRunning
                            ? .deleteActiveDownload
                            : .RLocalizable.deleteDownloadedGallery
                    )
                }
                return .none

            case .confirmationDialog(.presented(.confirmDelete)):
                return .send(.delegate(.confirmDelete))

            case .confirmationDialog:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}
