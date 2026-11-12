import AppComponents
public import AppModels
import AppTools
import ColorfulX
public import Kingfisher
import SFSafeSymbols
import Sharing
import SpringInterpolation
public import SwiftUI

#if DEBUG
import PreviewSupport
#endif

public struct GalleryCardCell: View {
    @SharedReader(.setting) private var setting: Setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title3) private var titleLineHeight: CGFloat = 24
    @ScaledMetric(relativeTo: .caption2) private var ratingLineHeight: CGFloat = 18
    @GalleryCoverMetrics(.homeCompact) private var compactCoverSize

    private let showsRichInformation: Bool
    private let usesCompactInformation: Bool
    private let maximumHeight: CGFloat?
    private let currentID: String
    private let colors: [Color]
    private let webImageSuccessAction: (RetrieveImageResult) -> Void

    private let gallery: Gallery

    // ColorfulX renders a full-bleed, opaque Metal gradient that always paints — unlike the
    // former Colorful view (translucent circles that only laid out while animated). The whole
    // `ColorfulView` is therefore gated on `showsGradient`: it is inserted only for the focused card,
    // in both appearances, and unselected cards show just the gray fallback. Light mode tones the
    // palette down to the fallback's own weight (`CardGradientTint`), so the focused card is tinted
    // by its cover without standing out more than its neighbors.
    // With Reduce Motion enabled, the gradient is seeded directly from the palette and its Metal
    // field is frozen in one fixed arrangement; the focus handoff remains an opacity cross-fade.
    // `animationSpeed` is the subjective, user-tunable motion knob (01-COLORFUL-UAT.md, D-19).
    private let animationSpeed: Double = 0.5

    public init(
        gallery: Gallery, currentID: String, colors: [Color],
        maximumHeight: CGFloat? = nil, showsRichInformation: Bool = false,
        usesCompactInformation: Bool = false,
        webImageSuccessAction: @escaping (RetrieveImageResult) -> Void
    ) {
        self.showsRichInformation = showsRichInformation
        self.usesCompactInformation = usesCompactInformation
        self.maximumHeight = maximumHeight
        self.gallery = gallery
        self.currentID = currentID
        self.colors = colors
        self.webImageSuccessAction = webImageSuccessAction
    }

    private var showsGradient: Bool {
        gallery.gid == currentID
    }

    public var body: some View {
        Group {
            if showsRichInformation {
                HStack(spacing: usesCompactInformation ? 16 : 30) {
                    GalleryCover(
                        url: gallery.coverURL,
                        style: usesCompactInformation ? .homeCompact : .homeSlideshow, contentMode: .fill,
                        onSuccess: webImageSuccessAction
                    )
                    VStack(alignment: .leading, spacing: 12) {
                        if usesCompactInformation {
                            HomeCompactSlideshowContent(gallery: gallery)
                        } else {
                            Text(gallery.displayTitle(prefersJapanese: setting.displayJapaneseTitle))
                                .accessibilityIdentifier("home_slideshow_title_\(gallery.id)")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            HomeSlideshowInformation(gallery: gallery)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(height: usesCompactInformation ? compactCoverSize.height : nil, alignment: .top)
                }
                .frame(
                    minHeight: usesCompactInformation
                        ? compactCoverSize.height : HomeSlideshowSizing.regularMinimumContentHeight
                )
            } else {
                GalleryCardHeightLayout(maximumHeight: maximumHeight.map({ max(0, $0 - 40) })) {
                    cardContent
                }
            }
        }
        .padding(
            showsRichInformation && !usesCompactInformation
                ? HomeSlideshowSizing.regularPadding : HomeSlideshowSizing.compactPadding
        )
        .frame(maxWidth: .infinity)
        .background {
            if showsGradient {
                CardGradientView(colors: colors, reduceMotion: reduceMotion, speed: animationSpeed)
                    // Cross-fade the focus handoff: the gradient is inserted/removed per focus
                    // change, and a bare conditional pops — the outgoing card's gradient would
                    // vanish in a single frame. A short opacity fade softens both edges without
                    // delaying the midline handoff that drives it (see HomeView+Sections).
                    .transition(.opacity)
            }
        }
        .background {
            Color.homeCardFallback
        }
        .clipShape(.rect(cornerRadius: 15))
        .animation(.easeInOut(duration: 0.5), value: showsGradient)
    }

    private var cardContent: some View {
        ViewThatFits(in: .vertical) {
            GalleryCardLayout(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                cover
                textColumn(titleLines: 4)
            }
            .fixedSize(horizontal: false, vertical: true)

            GalleryCardLayout(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                cover
                textColumn(titleLines: 2)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 16) {
                GalleryCover(
                    url: gallery.coverURL, style: .hero, contentMode: .fill,
                    maximumHeight: max(0, (maximumHeight ?? 190) - 40),
                    onSuccess: webImageSuccessAction
                )
                textColumn(titleLines: compactTitleLines)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var compactContentHeight: CGFloat {
        max(0, (maximumHeight ?? 190) - 40)
    }

    private var compactTitleLines: Int {
        max(1, min(2, Int((compactContentHeight - ratingLineHeight - 8) / titleLineHeight)))
    }

    private var cover: some View {
        GalleryCover(url: gallery.coverURL, style: .hero, contentMode: .fill, onSuccess: webImageSuccessAction)
    }

    /// Reserve the same preview height for every gallery at a given arrangement.
    /// The destination provides the complete title, while rating stays in this text column.
    private func textColumn(titleLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gallery.displayTitle(prefersJapanese: setting.displayJapaneseTitle))
                .accessibilityIdentifier("home_slideshow_title_\(gallery.id)")
                .font(.title3.bold())
                .lineLimit(titleLines, reservesSpace: true)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            rating
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rating: some View {
        ViewThatFits(in: .horizontal) {
            RatingView(rating: gallery.rating)
            Label {
                Text(gallery.rating.halfRounded, format: .number)
            } icon: {
                Image(systemSymbol: .starFill)
            }
        }
        .font(dynamicTypeSize.isAccessibilitySize ? .caption2 : .body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Color {
    /// The Home card's background wherever no gradient shows; the light-mode tint keeps its weight.
    static let homeCardFallback = Color.gray.opacity(0.2)
}

// Wraps `ColorfulView` so the gradient blooms in gradually instead of popping to full intensity.
// ColorfulX snaps the FIRST color set it receives (`initialSetup`) and only lerps SUBSEQUENT
// changes over `transitionSpeed`. Seeding the layer with a neutral dark color and then applying
// the real palette at appearance time turns the initial paint into an animated transition — reproducing
// the former Colorful view's gradual appearance. The seed is toned like any palette, and light mode
// tones every neutral to the gray fallback's weight, so there the bloom starts from the card's own
// gray. Fresh `@State` (the parent re-inserts this view per focus via `if showsGradient`) guarantees
// the bloom each time a card becomes current.
// Under Reduce Motion the same first-set snap is used the other way around: init seeds the real
// palette directly (no bloom — the first paint is already final), a `transitionSpeed` of 0 makes
// ColorfulX apply a palette that arrives later at once as well, `speed` 0 freezes the Metal field
// and `FixedSpeckleDirector` gives its points one arrangement, leaving a static gradient that looks
// the same every time and whose focus handoff remains the parent's opacity cross-fade. Skipping the
// late palette's fade is an owner-approved exception to Phase 16 D-29 (17-05-PLAN.md).
// Every palette is toned on its way to ColorfulX: dark mode holds it under `CardGradientCeiling` so the
// white text stays readable, light mode tints the gray card with it (`CardGradientTint`). An appearance
// or Contrast change reaches ColorfulX as a palette change and transitions like one.
private struct CardGradientView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
            color: displayedColors.map(toned),
            speed: .constant(reduceMotion ? 0 : speed),
            transitionSpeed: .constant(reduceMotion ? 0 : 6),
            animationDirector: reduceMotion ? FixedSpeckleDirector() : SpeckleAnimationRandomDirector()
        )
        // ColorfulX keeps the director its view was made with, so a Reduce Motion change rebuilds
        // the view to switch between the fixed arrangement and random movement.
        .id(reduceMotion)
        // `initial: true` fires this at appearance time with the unchanged palette, which is what
        // turns ColorfulX's first paint into an animated transition (see the type comment). It
        // replaces a former `onAppear` doing the same assignment, folding both into one modifier.
        .onChange(of: colors, initial: true) { _, newColors in
            displayedColors = newColors
        }
    }

    /// Card palettes hold absolute sRGB values (`ImageColors` builds them with `Color(.sRGB, …)`), which
    /// resolve the same in every environment; ColorfulX bridges them the same way, through `UIColor`
    /// without a trait collection.
    private func toned(_ color: Color) -> Color {
        let resolved = color.resolve(in: EnvironmentValues())
        return Color(
            colorScheme == .dark
                ? CardGradientCeiling(colorSchemeContrast).limit(resolved)
                : CardGradientTint.standard.tint(resolved)
        )
    }
}

/// Places the gradient's points in one fixed arrangement and never moves them, for Reduce Motion.
///
/// ColorfulX's default director scatters the points at random each time a gradient appears, so a
/// frozen gradient still arranged the same palette differently on every launch. The points follow
/// the R2 low-discrepancy sequence instead, which spreads any number of them evenly across the card,
/// as random placement does on average.
private final class FixedSpeckleDirector: SpeckleAnimationDirector {
    /// 1 / g and 1 / g², where g is the plastic number, the R2 sequence's generator.
    private static let step = (horizontal: 0.754_877_666_246_692_7, vertical: 0.569_840_290_998_053_2)

    override func initializeSpeckle(_ speckle: inout AnimatedMulticolorGradientView.Speckle, index: Int) {
        let horizontal = (0.5 + Double(index) * Self.step.horizontal).truncatingRemainder(dividingBy: 1)
        let vertical = (0.5 + Double(index) * Self.step.vertical).truncatingRemainder(dividingBy: 1)
        speckle.position.setCurrent(.init(x: horizontal, y: vertical))
        speckle.position.setTarget(.init(x: horizontal, y: vertical))
        view?.renderInputWasModified = true
    }
}

#if DEBUG
private let previewLongTitle =
    "(C99) [Sample Circle (Sample Artist)] An Exceptionally Long Doujinshi "
    + "Title That Wraps Across Several Lines To Exercise Truncation [English]"
private let previewCardColors: [Color] = ColorfulPreset.aurora.colors.map({ Color(uiColor: $0) })

private extension Gallery {
    static func previewFixture(identity: Int, title: String, rating: Float) -> Gallery {
        .init(
            gid: PreviewIdentifiers[identity].uuidString,
            token: "",
            title: title,
            rating: rating,
            tags: [],
            category: .doujinshi,
            uploader: "Anonymous",
            pageCount: 24,
            postedDate: .now,
            coverURL: nil,
            galleryURL: nil
        )
    }
}

#Preview("Focused", traits: .sizeThatFitsLayout) {
    GalleryCardCell(
        gallery: .preview, currentID: Gallery.preview.gid,
        colors: previewCardColors,
        webImageSuccessAction: { _ in }
    )
    .padding()
}

#Preview("Max rating, long title", traits: .sizeThatFitsLayout) {
    let gallery = Gallery.previewFixture(identity: 0, title: previewLongTitle, rating: 5)
    GalleryCardCell(
        gallery: gallery, currentID: gallery.gid,
        colors: previewCardColors,
        webImageSuccessAction: { _ in }
    )
    .padding()
}

#Preview("Min rating, short title", traits: .sizeThatFitsLayout) {
    let gallery = Gallery.previewFixture(identity: 1, title: "Doujin", rating: 0)
    GalleryCardCell(
        gallery: gallery, currentID: "other",
        colors: previewCardColors,
        webImageSuccessAction: { _ in }
    )
    .padding()
}

// The carousel's card width is a fraction of its container; 336 is that fraction on a 420-point
// screen, so the two sides of the rating gate are previewed against the width they actually get.
//
// Title and rating stay together while their typography follows the system text size.
#Preview("Long title, largest non-AX size", traits: .sizeThatFitsLayout) {
    let gallery = Gallery.previewFixture(identity: 2, title: previewLongTitle, rating: 4.5)
    GalleryCardCell(
        gallery: gallery, currentID: gallery.gid,
        colors: previewCardColors,
        webImageSuccessAction: { _ in }
    )
    .frame(width: 336)
    .padding()
    .environment(\.dynamicTypeSize, .xxxLarge)
}

// Accessibility layout gives the title its own row on narrow cards.
#Preview("Long title, accessibility size", traits: .sizeThatFitsLayout) {
    let gallery = Gallery.previewFixture(identity: 2, title: previewLongTitle, rating: 4.5)
    GalleryCardCell(
        gallery: gallery, currentID: gallery.gid,
        colors: previewCardColors,
        webImageSuccessAction: { _ in }
    )
    .frame(width: 336)
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}

// A wide accessibility card retains its horizontal cover/title arrangement.
#Preview("Wide card, accessibility size", traits: .sizeThatFitsLayout) {
    let gallery = Gallery.previewFixture(identity: 3, title: previewLongTitle, rating: 4.5)
    GalleryCardCell(
        gallery: gallery, currentID: gallery.gid,
        colors: previewCardColors,
        webImageSuccessAction: { _ in }
    )
    .frame(width: 700)
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
