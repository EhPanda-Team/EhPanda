import AppComponents
public import AppModels
public import ComposableArchitecture
import Foundation
import Resources

/// One row of the downloads list, owning that gallery's move and delete confirmations.
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
/// Move and delete confirmations belong to the item that presents them. The parent performs the
/// confirmed operations so client effects, analytics and failure handling remain shared by layouts.
@Reducer
public struct DownloadRowFeature: Sendable {
    public enum Delegate: Equatable, Sendable {
        case confirmDelete
        case move(String)
    }

    public enum Dialog: Equatable, Sendable {
        case confirmDelete
        case move(String)
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
        case moveButtonTapped(destinations: [String])
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

            case .moveButtonTapped(let destinations):
                guard state.download.displayStatus != .active, !destinations.isEmpty else { return .none }
                state.confirmationDialog = ConfirmationDialogState {
                    TextState(localized: .moveToFolder)
                } actions: {
                    for folder in destinations {
                        ButtonState(action: .move(folder)) {
                            TextState(folder)
                        }
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                }
                return .none

            case .confirmationDialog(.presented(.move(let folder))):
                return .send(.delegate(.move(folder)))

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
