import AppTools
public import SwiftUI

/// A `Toggle` pinned to the app's accent color.
///
/// SwiftUI switches follow the inherited `.tint`, so an ancestor's tint — or the
/// absence of one — can leave toggles rendering in an inconsistent color. Routing
/// every toggle through `AppToggle` applies `.tint(.accentColor)` in one place, so
/// the "on" state always uses the app accent. It mirrors the `Toggle` initializers
/// the app uses; trailing modifiers like `.labelsHidden()` still work because they
/// propagate through the environment to the wrapped `Toggle`.
///
/// It also gives every switch the pointer highlight (rule W): the system's highlight, in the switch track grown by
/// 6 pt (``SwitchTrackHoverShape``). The highlight is drawn around the track alone, because tapping the label does
/// not flip the switch.
public struct AppToggle<Label: View>: View {
    private let isOn: Binding<Bool>
    private let label: Label

    public init(isOn: Binding<Bool>, @ContentBuilder label: () -> Label) {
        self.isOn = isOn
        self.label = label()
    }

    public var body: some View {
        Toggle(isOn: isOn) { label }
            .tint(.accentColor)
            .interactiveHover(.highlight, in: SwitchTrackHoverShape())
    }
}

public extension AppToggle where Label == Text {
    /// Title + binding form, e.g. `AppToggle(.someKey, isOn: $flag)`.
    init(_ titleResource: LocalizedStringResource, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(titleResource) }
    }
}
