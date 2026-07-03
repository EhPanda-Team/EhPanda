import Foundation
import ComposableArchitecture

public extension TextState {
    /// Builds a `TextState` from a `LocalizedStringResource`, resolving it eagerly the same way a
    /// `String(localized:)`-wrapped construction would. The `localized:` label keeps this out of
    /// unlabeled overload resolution, so it never competes with `TextState`'s string-literal and
    /// `LocalizedStringKey` initializers inside `ButtonState`/`ConfirmationDialogState` builders.
    init(localized resource: LocalizedStringResource) {
        self.init(verbatim: String(localized: resource))
    }
}
