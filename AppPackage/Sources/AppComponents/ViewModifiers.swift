import AppModels
import AppTools
import Kingfisher
import ParserFeature
import SFSafeSymbols
import Sharing
import SwiftUI

public struct PrivacyMaskModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SharedReader(.privacyMaskBlur) private var blur

    public func body(content: Content) -> some View {
        content
            // Asymmetric on purpose: apply the mask instantly (`blur != 0`) but ease it out.
            // The blur is written on `.inactive`, exactly when iOS grabs the App Switcher
            // snapshot — a ramp-in would let that snapshot capture unblurred content. Only the
            // return-to-active fade (`blur == 0`) is animated, and Reduce Motion skips both.
            .animation(reduceMotion || blur != 0 ? nil : .linear(duration: 0.1)) {
                $0.blur(radius: blur)
            }
            .allowsHitTesting(blur < 1)
    }
}

extension View {
    @ContentBuilder public func withHorizontalSpacing(width: CGFloat = 8, height: CGFloat? = nil) -> some View {
        Color.clear.frame(width: width, height: height)
        self
        Color.clear.frame(width: width, height: height)
    }

    public func withArrow(isVisible: Bool = true) -> some View {
        HStack {
            self
                .frame(maxWidth: .infinity, alignment: .leading)

            // A disclosure chevron restates the row's own affordance, so it is never announced —
            // not even when drawn, which is why this is unconditional rather than a `visible(_:)`.
            Image(systemSymbol: .chevronRight)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .opacity(isVisible ? 0.5 : 0)
                .accessibilityHidden(true)
        }
    }

    /// Fades the view in or out, and takes it out of the accessibility tree while it is out.
    ///
    /// `opacity(0)` only stops a view being *drawn*. It stays in the layout — usually the whole
    /// point, since the space it reserves is what holds the surrounding arrangement still — but it
    /// also stays an accessibility element, so VoiceOver goes on reading a label for something
    /// nobody can see and Voice Control still offers it a number. Visibility and accessibility have
    /// to change together or they drift apart, which is why this pairs them once rather than
    /// leaving `.opacity` and `.accessibilityHidden` to be written side by side at every call site.
    ///
    /// Use it wherever a view is hidden by fading rather than by leaving the hierarchy: a crossfade
    /// between content and its empty state, an idle control against the spinner that replaces it, a
    /// placeholder that exists only to reserve space. A view that is merely *dimmed* is still
    /// visible and does not belong here.
    ///
    /// The hidden state is applied through `isEnabled:` rather than as `accessibilityHidden(false)`
    /// on a visible view, because the two are not symmetric. `accessibilityHidden(false)` is not
    /// "no opinion": it is an explicit *un*-hide that re-exposes the descendants a nested hide had
    /// already taken out of the tree. A visible `visible(true)` therefore used to cancel the hides
    /// below it, and the reader's slider-preview strip — hidden by its own `visible(false)` inside
    /// the shown control panel — was read out in full (Phase 16 VO-2; the V3 isolation build in
    /// `16-SWEEP.md § Design proposals (16-25) › P-VO2` proved the ancestor's `false` was the
    /// cause). With `isEnabled:` a visible view writes no accessibility-hidden value at all, so it
    /// states only its own visibility and never overrides a descendant's.
    public func visible(_ isVisible: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .accessibilityHidden(true, isEnabled: !isVisible)
    }

    public func privacyMask() -> some View {
        modifier(PrivacyMaskModifier())
    }

    public func synchronize<Value: Equatable>(
        _ first: Binding<Value>,
        _ second: Binding<Value>,
        initial: (first: Bool, second: Bool) = (false, false)
    ) -> some View {
        self
            .onChange(of: first.wrappedValue, initial: initial.first) { _, newValue in
                second.wrappedValue = newValue
            }
            .onChange(of: second.wrappedValue, initial: initial.second) { _, newValue in
                first.wrappedValue = newValue
            }
    }

    public func synchronize<Value>(
        _ first: Binding<Value>,
        _ second: FocusState<Value>.Binding,
        initial: (first: Bool, second: Bool) = (false, false)
    ) -> some View {
        self
            .onChange(of: first.wrappedValue, initial: initial.first) { _, newValue in
                second.wrappedValue = newValue
            }
            .onChange(of: second.wrappedValue, initial: initial.second) { _, newValue in
                first.wrappedValue = newValue
            }
    }
}

public struct PlainLinearProgressViewStyle: ProgressViewStyle {
    public init() {}

    public func makeBody(configuration: ProgressViewStyleConfiguration) -> some View {
        ProgressView(value: CGFloat(configuration.fractionCompleted ?? 0), total: 1)
    }
}
extension ProgressViewStyle where Self == PlainLinearProgressViewStyle {
    public static var plainLinear: PlainLinearProgressViewStyle {
        PlainLinearProgressViewStyle()
    }
}

// MARK: Image Modifier
public struct CornersModifier: ImageModifier {
    let radius: CGFloat?

    public init(radius: CGFloat? = nil) {
        self.radius = radius
    }

    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        if let radius = radius {
            return image.withRoundedCorners(radius: radius) ?? image
        } else {
            return image
        }
    }
}

public struct OffsetModifier: ImageModifier {
    private let size: CGSize?
    private let offset: CGSize?

    public init(size: CGSize?, offset: CGSize?) {
        self.size = size
        self.offset = offset
    }

    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        guard let size = size, let offset = offset
        else { return image }

        return image.cropping(size: size, offset: offset) ?? image
    }
}

public struct RoundedOffsetModifier: ImageModifier {
    private let size: CGSize?
    private let offset: CGSize?

    public init(size: CGSize?, offset: CGSize?) {
        self.size = size
        self.offset = offset
    }

    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        guard let size = size, let offset = offset,
              let croppedImg = image.cropping(size: size, offset: offset),
              let roundedCroppedImg = croppedImg.withRoundedCorners(radius: 5)
        else { return image.withRoundedCorners(radius: 5) ?? image }

        return roundedCroppedImg
    }
}

public struct WebtoonModifier: ImageModifier {
    private let minAspect: CGFloat
    private let idealAspect: CGFloat

    public init(minAspect: CGFloat, idealAspect: CGFloat) {
        self.minAspect = minAspect
        self.idealAspect = idealAspect
    }

    public func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        let width = image.size.width
        let height = image.size.height
        let idealHeight = width / idealAspect
        guard width / height < minAspect else { return image }
        return image.cropping(size: CGSize(width: width, height: idealHeight), offset: .zero) ?? image
    }
}

extension KFImage {
    public func defaultModifier(withRoundedCorners: Bool = true) -> KFImage {
        self
            .imageModifier(CornersModifier(
                radius: withRoundedCorners ? 5 : nil
            ))
            .fade(duration: 0.25)
            .resizable()
    }
}

public struct PreviewResolver {
    public static func getPreviewConfigs(originalURL: URL?) -> (url: URL?, modifier: ImageModifier) {
        guard let url = originalURL,
              let info = Parser.parsePreviewConfigs(url: url)
        else {
            return (originalURL, RoundedOffsetModifier(size: nil, offset: nil))
        }
        return (info.plainURL, RoundedOffsetModifier(size: info.size, offset: info.offset))
    }
}
