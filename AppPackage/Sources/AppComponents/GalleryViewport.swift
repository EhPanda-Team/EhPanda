public import Observation
public import SwiftUI

/// A capture signal installed in the environment before the first render and kept stable thereafter.
/// Changing an environment value reconfigures unrelated platform machinery: on the iOS 27 Simulator,
/// the first root environment change shrinks navigation toolbar glyphs at XXL and AX5. Mutating this
/// object's property instead invalidates only the sampling modifiers that observe it.
@MainActor
@Observable
public final class VisibleViewportSampling {
    public var isFrozen = false

    public init() {}
}

public extension EnvironmentValues {
    /// Production leaves this nil so each view continues sampling its own visible container.
    @Entry var visibleViewportSampling: VisibleViewportSampling?
}

public extension View {
    /// Samples the container size only while the container represents the visible viewport.
    /// Full-content capture freezes sampling before enlarging the container, so viewport-based layout rules
    /// retain their own native measurements. Unfreezing delivers the current size if it changed while frozen.
    func onVisibleViewportChange(_ action: @escaping (CGSize) -> Void) -> some View {
        modifier(VisibleViewportMeasurement(action: action))
    }
}

private struct VisibleViewportMeasurement: ViewModifier {
    @Environment(\.visibleViewportSampling) private var sampling
    @State private var latestSize: CGSize?
    @State private var lastForwardedSize: CGSize?
    let action: (CGSize) -> Void

    private var isFrozen: Bool { sampling?.isFrozen ?? false }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self, of: \.size, action: geometryChanged)
            .onChange(of: isFrozen, freezeChanged)
    }

    private func geometryChanged(_ size: CGSize) {
        latestSize = size
        guard !isFrozen else { return }
        lastForwardedSize = size
        action(size)
    }

    private func freezeChanged() {
        guard !isFrozen, let latestSize, latestSize != lastForwardedSize else { return }
        lastForwardedSize = latestSize
        action(latestSize)
    }
}

/// Uses the available app viewport, so a windowed tablet can adopt the compact gallery rules.
public struct GalleryViewport {
    public let size: CGSize
    public let isRegularWidth: Bool

    public init(size: CGSize, isRegularWidth: Bool) {
        self.size = size
        self.isRegularWidth = isRegularWidth
    }

    public var isLarge: Bool {
        isRegularWidth && size.width >= 744 && size.height >= 600
    }

    public var isLandscape: Bool { size.width > size.height }

    public var maximumSlideshowHeight: CGFloat {
        let fraction: CGFloat = isLarge
            ? (isLandscape ? 0.4 : 0.5)
            : (isLandscape ? 0.8 : 0.7)
        return size.height * fraction
    }

    public var minimumThumbnailColumns: Int {
        isLarge && isLandscape ? 3 : 2
    }
}
