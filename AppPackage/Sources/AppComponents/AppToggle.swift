import SwiftUI

/// A `Toggle` pinned to the app's accent color.
///
/// SwiftUI switches follow the inherited `.tint`, so an ancestor's tint — or the
/// absence of one — can leave toggles rendering in an inconsistent color. Routing
/// every toggle through `AppToggle` applies `.tint(.accentColor)` in one place, so
/// the "on" state always uses the app accent. It mirrors the `Toggle` initializers
/// the app uses; trailing modifiers like `.labelsHidden()` still work because they
/// propagate through the environment to the wrapped `Toggle`.
public struct AppToggle<Label: View>: View {
    private let isOn: Binding<Bool>
    private let label: Label

    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.isOn = isOn
        self.label = label()
    }

    public var body: some View {
        Toggle(isOn: isOn) { label }
            .tint(.accentColor)
    }
}

public extension AppToggle where Label == Text {
    /// Title + binding form, e.g. `AppToggle(.someKey, isOn: $flag)`.
    init(_ titleResource: LocalizedStringResource, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(titleResource) }
    }
}
