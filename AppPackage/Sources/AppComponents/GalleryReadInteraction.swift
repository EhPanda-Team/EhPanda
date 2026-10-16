import Resources
public import SwiftUI

/// A secondary read gesture that preserves a button's native default activation and semantics.
public struct GalleryReadInteraction: ViewModifier {
    private let detailAction: () -> Void
    private let readAction: (() -> Void)?

    public init(detailAction: @escaping () -> Void, readAction: (() -> Void)?) {
        self.detailAction = detailAction
        self.readAction = readAction
    }

    public func body(content: Content) -> some View {
        if let readAction {
            content
                // List's automatic row activation bypasses tap-count arbitration.
                .buttonStyle(.borderless)
                .contentShape(.rect)
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded { readAction() }
                        .exclusively(before: TapGesture().onEnded { detailAction() })
                )
                .accessibilityActions {
                    Button(.RLocalizable.read, action: readAction)
                }
        } else {
            content
        }
    }
}
