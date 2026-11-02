import AppComponents
import AppModels
import AppTools
import Foundation
@testable import HomeFeature
import SwiftUI
import Testing
import UIKit

struct GalleryCoverLayoutTests {
    @Test
    func coverFramesShareTheRequestedBookProportion() {
        #expect(Defaults.ImageSize.coverAspect == 0.707)
        #expect(Defaults.ImageSize.rowAspect == 0.707)
        #expect(Defaults.ImageSize.headerAspect == 0.707)
        #expect(GalleryCoverStyle.aspectRatio == 0.707)
        let styles: [GalleryCoverStyle] = [
            .compact, .standard, .hero, .homeCompact, .homeSlideshow, .homeFrontPage, .homeRanking
        ]
        for style in styles {
            for displayScale: CGFloat in [2, 3] {
                for scale: CGFloat in [1, 1.25, 2] {
                    let size = style.size(scale: scale, displayScale: displayScale)
                    #expect(abs(size.width * displayScale - size.height * displayScale * 0.707) <= 0.5)
                    #expect(size.height <= (style.baseHeight * 1.25 * displayScale).rounded() / displayScale)
                }
            }
        }
    }

    @Test
    func viewportRulesRespectWindowSizeAndOrientation() {
        let phone = GalleryViewport(size: CGSize(width: 420, height: 800), isRegularWidth: false)
        let phoneLandscape = GalleryViewport(size: CGSize(width: 800, height: 420), isRegularWidth: false)
        let portrait = GalleryViewport(size: CGSize(width: 834, height: 1100), isRegularWidth: true)
        let landscape = GalleryViewport(size: CGSize(width: 1210, height: 734), isRegularWidth: true)
        let narrowWindow = GalleryViewport(size: CGSize(width: 700, height: 650), isRegularWidth: true)
        let shortWindow = GalleryViewport(size: CGSize(width: 1000, height: 500), isRegularWidth: true)
        #expect(phone.maximumSlideshowHeight == 560)
        #expect(phoneLandscape.maximumSlideshowHeight == 336)
        #expect(portrait.maximumSlideshowHeight == 550)
        #expect(abs(landscape.maximumSlideshowHeight - 293.6) < 0.01)
        #expect(landscape.minimumThumbnailColumns == 3)
        #expect(portrait.minimumThumbnailColumns == 2)
        #expect(!narrowWindow.isLarge && narrowWindow.minimumThumbnailColumns == 2)
        #expect(!shortWindow.isLarge && shortWindow.maximumSlideshowHeight == 400)
    }

    @MainActor
    @Test
    func coverRolesKeepTheirHierarchyAcrossTheTextRange() {
        // Hosting measurements round fractional points to display pixels.
        for textSize in DynamicTypeSize.allCases {
            let compact = measure(GalleryCover(url: nil, style: .compact), textSize: textSize)
            let standard = measure(GalleryCover(url: nil, style: .standard), textSize: textSize)
            let hero = measure(GalleryCover(url: nil, style: .hero), textSize: textSize)
            #expect(compact.height >= 90 && compact.height <= 113)
            #expect(standard.height >= 120 && standard.height <= 150)
            #expect(hero.height >= 150 && hero.height <= 188)
            #expect(compact.height < standard.height)
            #expect(standard.height < hero.height)
            #expect(abs(hero.width - hero.height * 0.707) < 1)
            if textSize == .large {
                #expect(hero.height == 150)
            }
            if textSize == .accessibility5 {
                #expect(abs(compact.height - 112.5) < 1)
                #expect(standard.height == 150)
                #expect(abs(hero.height - 187.5) < 1)
            }
        }
    }

    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5], [CGFloat(336), 700])
    func cardHeightDoesNotDependOnTitleLength(textSize: DynamicTypeSize, width: CGFloat) {
        let short = card(title: "Short title")
        let long = card(title: String(repeating: "A long gallery title with many words ", count: 8))
        let shortSize = measure(short, textSize: textSize, width: width)
        let longSize = measure(long, textSize: textSize, width: width)
        #expect(abs(shortSize.height - longSize.height) < 1)
        #expect(shortSize.width <= width)
        #expect(longSize.width <= width)
        #expect(shortSize.height >= 190)
    }

    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .accessibility5], [CGFloat(180), 300, 400])
    func cardRespectsViewportHeightBudget(textSize: DynamicTypeSize, maximumHeight: CGFloat) {
        let content = card(
            title: String(repeating: "A long gallery title ", count: 12),
            maximumHeight: maximumHeight
        )
        let size = measure(content, textSize: textSize, width: 336)
        #expect(size.height <= maximumHeight + 1)
        #expect(size.width <= 337)
    }

    @MainActor
    @Test
    func constrainedCardDoesNotExpandToFillTheCeiling() {
        let content = card(title: String(repeating: "Long title ", count: 20), maximumHeight: 350)
        let size = measure(content, textSize: .accessibility5, width: 336)
        #expect(size.height < 300)
    }

    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .accessibility1, .accessibility3, .accessibility5])
    func richSlideshowGrowsForMetadataWithoutClipping(textSize: DynamicTypeSize) {
        let gallery = Gallery(
            gid: "rich-card", token: "", title: "[Studio] A  Journey [English]", rating: 4.5,
            tags: [], category: .doujinshi, pageCount: 48,
            postedDate: .now, coverURL: nil, galleryURL: nil
        )
        let content = GalleryCardCell(
            gallery: gallery, currentID: gallery.id, colors: [], maximumHeight: 290,
            showsRichInformation: true, webImageSuccessAction: { _ in }
        )
        // The title's flexible frame takes any height it is offered, so measure the ideal height:
        // the carousel lays its cards out at that height through its own `fixedSize`.
        let size = measure(content.fixedSize(horizontal: false, vertical: true), textSize: textSize, width: 1000)
        #expect(size.width <= 1000)
        #expect(size.height >= 274)
        if textSize == .large { #expect(size.height < 300) }
        if textSize == .accessibility5 { #expect(size.height > 290) }
    }

    @MainActor
    @Test(arguments: [GalleryCoverStyle.hero, .homeCompact], [DynamicTypeSize.large, .accessibility5])
    func frontPageCoverMatchesItsSlideshowCeiling(style: GalleryCoverStyle, textSize: DynamicTypeSize) {
        let slideshow = measure(GalleryCover(url: nil, style: style), textSize: textSize)
        let frontPage = measure(
            HomeFrontPageCell(
                gallery: .preview, showsRichInformation: true, maximumCoverHeight: slideshow.height
            ),
            textSize: textSize
        )
        #expect(abs(frontPage.width - slideshow.width) < 1)
    }

    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .accessibility1, .accessibility3, .accessibility5], [false, true])
    func slideshowNeverExceedsReferenceAspectRatio(textSize: DynamicTypeSize, compact: Bool) {
        let cover = measure(GalleryCover(url: nil, style: .homeCompact), textSize: textSize)
        let minimumHeight = compact ? cover.height + 40 : 274
        for availableWidth: CGFloat in [402, 818, 900, 901, 939, 1210] {
            let width = HomeSlideshowSizing.cardWidth(
                availableWidth: availableWidth, minimumHeight: minimumHeight, showsRichInformation: true
            )
            let content = GalleryCardCell(
                gallery: .preview, currentID: "", colors: [], showsRichInformation: true,
                usesCompactInformation: compact, webImageSuccessAction: { _ in }
            )
            let size = measure(content, textSize: textSize, width: width)
            #expect(size.width / size.height <= 751.0 / 274.0 + 0.01)
            #expect(size.width <= availableWidth * 0.9 + 1)
            if compact && textSize == .large { #expect(abs(size.height - 205) < 1) }
        }
    }

    @MainActor
    @Test(arguments: [DynamicTypeSize.large, .accessibility5], [CGFloat(180), 300])
    func splitSlideshowKeepsHeightBudgetAndReferenceProportion(textSize: DynamicTypeSize, maximumHeight: CGFloat) {
        let cover = measure(GalleryCover(url: nil, style: .hero), textSize: textSize)
        let width = HomeSlideshowSizing.cardWidth(
            availableWidth: 1000, minimumHeight: min(cover.height + 40, maximumHeight),
            showsRichInformation: false
        )
        let size = measure(card(title: "Short title", maximumHeight: maximumHeight), textSize: textSize, width: width)
        #expect(size.width / size.height <= 751.0 / 274.0 + 0.01)
        #expect(size.height <= maximumHeight + 1)
    }

    @Test(arguments: [CGFloat(375), 390, 402, 420, 440, 466, 669, 744, 834, 1210], [false, true])
    func viewportOverhangKeepsTheNeighborInReachOfVoiceOver(availableWidth: CGFloat, showsRichInformation: Bool) {
        let cardWidth = HomeSlideshowSizing.cardWidth(
            availableWidth: availableWidth, minimumHeight: 274, showsRichInformation: showsRichInformation
        )
        let overhang = HomeSlideshowSizing.viewportOverhang(availableWidth: availableWidth, cardWidth: cardWidth)
        let onScreen = (availableWidth - cardWidth) / 2 - HomeSlideshowSizing.cardSpacing
        #expect(cardWidth == cardWidth.rounded())
        #expect(onScreen + overhang >= HomeSlideshowSizing.minimumNeighborExposure)
        #expect(overhang == max(0, HomeSlideshowSizing.minimumNeighborExposure - onScreen))
    }

    @Test(arguments: [CGFloat(834), 1194, 1210])
    func viewportOverhangStaysOutOfLayoutsThatReachTheThresholdThemselves(availableWidth: CGFloat) {
        let cardWidth = HomeSlideshowSizing.cardWidth(
            availableWidth: availableWidth, minimumHeight: 274, showsRichInformation: true
        )
        #expect(HomeSlideshowSizing.viewportOverhang(availableWidth: availableWidth, cardWidth: cardWidth) == 0)
    }

    @Test
    func slideshowTagsExcludeLanguageCategoryAndDuplicates() {
        func tag(_ namespace: String, _ texts: [String]) -> GalleryTag {
            .init(rawNamespace: namespace, contents: texts.map { text in
                .init(rawNamespace: namespace, text: text, isVotedUp: false, isVotedDown: false, voteStrength: .strong)
            })
        }
        var gallery = Gallery.preview
        gallery.tags = [
            tag("language", ["english", "translated"]),
            tag("misc", ["Doujinshi", "watercolor", "Watercolor", "landscape", "full color", "extra"])
        ]
        #expect(gallery.homeSlideshowTags.map(\.text) == ["watercolor", "landscape", "full color"])
        gallery.tags = []
        #expect(gallery.homeSlideshowTags.isEmpty)
    }

    @MainActor
    private func card(title: String, maximumHeight: CGFloat? = nil) -> some View {
        let gallery = Gallery(
            gid: "cover-layout", token: "", title: title, rating: 4.5, tags: [],
            category: .doujinshi, uploader: "Sample", pageCount: 24,
            postedDate: .now, coverURL: nil, galleryURL: nil
        )
        return GalleryCardCell(
            gallery: gallery, currentID: gallery.gid, colors: [],
            maximumHeight: maximumHeight, webImageSuccessAction: { _ in }
        )
    }

    @MainActor
    private func measure<Content: View>(
        _ content: Content, textSize: DynamicTypeSize, width: CGFloat = 700
    ) -> CGSize {
        let host = UIHostingController(rootView: content.environment(\.dynamicTypeSize, textSize))
        return host.sizeThatFits(in: CGSize(width: width, height: 2000))
    }
}
