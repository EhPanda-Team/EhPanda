import SwiftUI

/// The size classes of the app's window, as the root view reads them from its environment.
///
/// Reducers cannot read the environment, yet the app root decides how a screen opened from a tab
/// is shown before any view of that screen exists, and a launch automation opens one without any
/// tap at all. So the root view reports the window's size classes to `AppReducer`, the way it
/// reports `scenePhase`, and reports them again on every change.
struct WindowSizeClasses: Equatable, Sendable {
    var horizontal: UserInterfaceSizeClass?
    var vertical: UserInterfaceSizeClass?

    /// Whether a screen opened from a tab is presented as a sheet rather than pushed onto the tab's
    /// stack. Only a window regular in both dimensions leaves room around a sheet: a large iPhone in
    /// landscape is regular in width but compact in height, so it pushes, as does a folded iPhone
    /// Duo or a narrow iPad window.
    var presentsModally: Bool {
        horizontal == .regular && vertical == .regular
    }
}
