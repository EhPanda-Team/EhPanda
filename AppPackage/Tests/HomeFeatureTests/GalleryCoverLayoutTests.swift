import AppComponents
import AppModels
import Dependencies
import DeviceClient
import Foundation
@testable import HomeFeature
import SwiftUI
import Testing
import UIKit

struct GalleryCoverLayoutTests {
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
            #expect(abs(hero.width - hero.height * 8 / 11) < 1)
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
    private func card(title: String, maximumHeight: CGFloat? = nil) -> some View {
        let gallery = Gallery(
            gid: "cover-layout", token: "", title: title, rating: 4.5, tags: [],
            category: .doujinshi, uploader: "Sample", pageCount: 24,
            postedDate: .now, coverURL: nil, galleryURL: nil
        )
        return withDependencies {
            $0.deviceClient = .noop
        } operation: {
            GalleryCardCell(
                gallery: gallery, currentID: gallery.gid, colors: [],
                maximumHeight: maximumHeight, webImageSuccessAction: { _ in }
            )
        }
    }

    @MainActor
    private func measure<Content: View>(
        _ content: Content, textSize: DynamicTypeSize, width: CGFloat = 700
    ) -> CGSize {
        let host = UIHostingController(rootView: content.environment(\.dynamicTypeSize, textSize))
        return host.sizeThatFits(in: CGSize(width: width, height: 2000))
    }
}
