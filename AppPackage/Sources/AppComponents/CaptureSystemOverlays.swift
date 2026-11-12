#if DEBUG
public import SwiftUI

public extension EnvironmentValues {
    /// Capture chrome follows presented screens, including readers with their own overlay preference.
    /// Ordinary launches leave this nil and retain each screen's native visibility policy.
    @Entry var captureSystemOverlayVisibility: Visibility?
}
#endif
