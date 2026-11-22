import Resources
public import SwiftUI

/// A secondary read gesture that preserves a button's native default activation and semantics.
///
/// A gallery entry has two routes (owner decisions D89 and D146): a single tap opens Detail and a
/// double tap reads, and a single tap on the cover, which a cell marks with `galleryReadCover()`,
/// reads as well. One gesture arbitrates all three, so a tap on the cover never also opens Detail.
/// The cover's frame reaches the gesture as an anchor preference, keeping the cells free of any
/// interaction state. VoiceOver keeps the entry as one element: its default activation opens Detail
/// and the Read action reads, so no route depends on where a finger lands.
public struct GalleryReadInteraction: ViewModifier {
    @State private var coverFrame: CGRect?
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
                // The background shares the content's frame, so the cover resolves into the space the
                // tap's location is reported in.
                .backgroundPreferenceValue(GalleryReadCoverKey.self) { anchor in
                    Color.clear.onGeometryChange(for: CGRect?.self) { proxy in
                        anchor.map({ proxy[$0] })
                    } action: { frame in
                        coverFrame = frame
                    }
                }
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded { readAction() }
                        .exclusively(before: SpatialTapGesture().onEnded { tap in
                            if coverFrame?.contains(tap.location) == true {
                                readAction()
                            } else {
                                detailAction()
                            }
                        })
                )
                .accessibilityActions {
                    Button(.RLocalizable.read, action: readAction)
                }
        } else {
            content
        }
    }
}

extension View {
    /// Marks this view as a gallery cell's cover: inside `GalleryReadInteraction`, a tap on it reads.
    public func galleryReadCover() -> some View {
        anchorPreference(key: GalleryReadCoverKey.self, value: .bounds) { $0 }
    }
}

/// The bounds of the one cover in a gallery cell.
private struct GalleryReadCoverKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
