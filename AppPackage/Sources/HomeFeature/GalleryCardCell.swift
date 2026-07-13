import SwiftUI
import AppModels
import AppComponents
import ColorfulX
import Kingfisher
import AppTools
import Dependencies
import DeviceClient

public struct GalleryCardCell: View {
    @Dependency(\.deviceClient) private var deviceClient
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let currentID: String
    private let colors: [Color]
    private let webImageSuccessAction: (RetrieveImageResult) -> Void

    private let gallery: Gallery

    // ColorfulX renders a full-bleed, opaque Metal gradient that always paints — unlike the
    // former Colorful view (translucent circles that only laid out when `animated`). To keep
    // the pre-migration behavior, the whole `ColorfulView` is gated on `animated`: it is inserted
    // only for the focused card in dark mode. Unselected cards and light mode show just the gray
    // fallback, and the cover-color analysis is skipped until dark (see `handleCoverSuccess`).
    // With Reduce Motion enabled, the gradient is seeded directly from the palette and its Metal
    // field is frozen; the focus handoff remains an opacity cross-fade. `animationSpeed` is the
    // subjective, user-tunable motion knob (01-COLORFUL-UAT.md, D-19).
    private let animationSpeed: Double = 0.5

    // Retains the last cover-image result so color analysis can be deferred: light mode never
    // shows the gradient, so analysis is skipped there; switching to dark replays this result to
    // compute the focused card's colors on demand, without reloading the cover.
    @State private var lastImageResult: RetrieveImageResult?

    public init(
        gallery: Gallery, currentID: String, colors: [Color],
        webImageSuccessAction: @escaping (RetrieveImageResult) -> Void
    ) {
        self.gallery = gallery
        self.currentID = currentID
        self.colors = colors
        self.webImageSuccessAction = webImageSuccessAction
    }

    private var animated: Bool {
        guard colorScheme == .dark else { return false }
        return gallery.gid == currentID
    }
    private var title: String {
        let trimmedTitle = gallery.trimmedTitle
        guard deviceClient.deviceType() != .pad, trimmedTitle.count > 20 else {
            return gallery.title
        }
        return trimmedTitle
    }

    public var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            if animated {
                CardGradientView(colors: colors, reduceMotion: reduceMotion, speed: animationSpeed)
                    // Cross-fade the focus handoff: the gradient is inserted/removed per focus
                    // change, and a bare conditional pops — the outgoing card's gradient would
                    // vanish in a single frame. A short opacity fade softens both edges without
                    // delaying the midline handoff that drives it (see HomeView+Sections).
                    .transition(.opacity)
            }
            HStack {
                KFImage(gallery.coverURL)
                    .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                    .onSuccess(handleCoverSuccess).defaultModifier().scaledToFill()
                    .frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)
                    .cornerRadius(5)
                VStack(alignment: .leading) {
                    Text(title).font(.title3.bold()).lineLimit(4)
                    Spacer()
                    RatingView(rating: gallery.rating).foregroundColor(.yellow)
                }
                .padding(.leading, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .cornerRadius(15)
        .animation(.easeInOut(duration: 0.5), value: animated)
        .onChange(of: colorScheme) { _, newScheme in
            guard newScheme == .dark, let lastImageResult else { return }
            webImageSuccessAction(lastImageResult)
        }
    }

    // Color analysis is only meaningful when the gradient is visible (dark mode). The result is
    // always retained so a later light → dark switch can trigger analysis without reloading.
    private func handleCoverSuccess(_ result: RetrieveImageResult) {
        lastImageResult = result
        guard colorScheme == .dark else { return }
        webImageSuccessAction(result)
    }
}

// Wraps `ColorfulView` so the gradient blooms in gradually instead of popping to full intensity.
// ColorfulX snaps the FIRST color set it receives (`initialSetup`) and only lerps SUBSEQUENT
// changes over `transitionSpeed`. Seeding the layer with a neutral dark color and then applying
// the real palette on appear turns the initial paint into an animated transition — reproducing
// the former Colorful view's gradual appearance. Fresh `@State` (the parent re-inserts this view
// per focus via `if animated`) guarantees the bloom each time a card becomes current.
// Under Reduce Motion the same first-set snap is used the other way around: init seeds the real
// palette directly (no bloom — the first paint is already final) and `speed` 0 freezes the Metal
// field, leaving a static gradient whose focus handoff remains the parent's opacity cross-fade.
private struct CardGradientView: View {
    let colors: [Color]
    let reduceMotion: Bool
    let speed: Double

    @State private var displayedColors: [Color]

    init(colors: [Color], reduceMotion: Bool, speed: Double) {
        self.colors = colors
        self.reduceMotion = reduceMotion
        self.speed = speed
        _displayedColors = State(initialValue: reduceMotion ? colors : [.black])
    }

    var body: some View {
        ColorfulView(
            color: displayedColors,
            speed: .constant(reduceMotion ? 0 : speed),
            transitionSpeed: .constant(6)
        )
        .onAppear { displayedColors = colors }
        .onChange(of: colors) { _, newColors in displayedColors = newColors }
    }
}

struct GalleryCardCell_Previews: PreviewProvider {
    static var previews: some View {
        let gallery = Gallery.preview
        GalleryCardCell(
            gallery: gallery, currentID: gallery.gid,
            colors: ColorfulPreset.aurora.colors.map { Color($0) },
            webImageSuccessAction: { _ in }
        )
        .previewLayout(.fixed(width: 300, height: 206)).padding()
    }
}
