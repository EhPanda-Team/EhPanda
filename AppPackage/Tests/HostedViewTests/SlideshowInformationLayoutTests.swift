import AppModels
import ComposableArchitecture
import Foundation
@testable import HomeFeature
import Sharing
import SwiftUI
import Testing
import UIKit

/// No stat label of the Home slideshow card is ever broken mid-word (the owner's C9 decision, 19-23).
///
/// At the largest accessibility size the stat labels did not fit their column: "Rat-ing" and "Be-wer-tung" on the
/// iPhone in portrait, "Catego-ry" and "Kate-gorie" on the iPad. The owner chose a last fallback, one stat per line as
/// "label value", below the cover on the iPhone and under the title on the iPad. These tests host the card at the
/// width it has in the app (the carousel gives a card 0.9 of the 420 pt iPhone scene, 378 pt, and 751 pt on the iPad)
/// and read each label's accessibility frame. A label is whole when it is exactly one line tall, which is the height
/// of any other caption-sized text in the same environment.
@MainActor
struct SlideshowInformationLayoutTests {
    private static let phoneCardWidth: CGFloat = 378
    private static let padCardWidth: CGFloat = 751
    private static let tolerance: CGFloat = 0.5
    private static let gallery = Gallery(
        gid: "1", token: "a", title: "A Gallery With A Title That Wraps Over More Than One Line", rating: 4.5,
        tags: [], category: .doujinshi, uploader: "Visual Fixture", pageCount: 24,
        postedDate: Date(timeIntervalSince1970: 1_700_000_000), coverURL: nil, galleryURL: nil
    )

    @Test(arguments: ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"])
    func everyStatLabelOfTheCompactCardIsOneLineAndBelowTheCoverAtTheLargestAccessibilitySize(
        identifier: String
    ) throws {
        let layout = try Self.read(Self.card(compact: true), width: Self.phoneCardWidth, identifier: identifier)
        let title = try #require(layout.title, "The card has no title element; \(layout.labels).")
        // VoiceOver reads the title, then the stats, whichever side of the cover the stats are on.
        let titleIndex = try #require(layout.labels.firstIndex(of: Self.gallery.title))
        let statIndex = try #require(layout.labels.firstIndex(of: Self.label(.homeMetadataRating, identifier)))
        #expect(titleIndex < statIndex, "\(identifier): the stats are read before the title; \(layout.labels).")
        for stat in Self.statLabels(identifier: identifier, includesRating: true) {
            let frame = try #require(layout.frame(labelled: stat), "No element reads \(stat); \(layout.labels).")
            #expect(
                abs(frame.height - layout.singleLine) <= Self.tolerance,
                "\(identifier): \(stat) is \(frame.height) pt tall, one line is \(layout.singleLine)."
            )
            #expect(
                frame.minX < title.minX - 1,
                "\(identifier): \(stat) starts at \(frame.minX), beside the cover (the title starts at \(title.minX))."
            )
        }
    }

    @Test
    func theCompactCardKeepsItsStatsBesideTheCoverAtTheDefaultSize() throws {
        let layout = try Self.read(
            Self.card(compact: true), width: Self.phoneCardWidth, identifier: "en", size: .large
        )
        let title = try #require(layout.title, "The card has no title element; \(layout.labels).")
        for stat in Self.statLabels(identifier: "en", includesRating: true) {
            let frame = try #require(layout.frame(labelled: stat), "No element reads \(stat); \(layout.labels).")
            #expect(
                frame.minX >= title.minX - 1,
                "\(stat) starts at \(frame.minX), below the cover (the title starts at \(title.minX))."
            )
        }
    }

    @Test(arguments: ["en", "de"])
    func everyStatLabelAndTheCategoryOfTheRegularCardIsOneLineAtTheLargestAccessibilitySize(
        identifier: String
    ) throws {
        let layout = try Self.read(Self.card(compact: false), width: Self.padCardWidth, identifier: identifier)
        let category = Self.label(Self.gallery.category.value, identifier)
        for label in Self.statLabels(identifier: identifier, includesRating: false) {
            let frame = try #require(layout.frame(labelled: label), "No element reads \(label); \(layout.labels).")
            #expect(
                abs(frame.height - layout.singleLine) <= Self.tolerance,
                "\(identifier): \(label) is \(frame.height) pt tall, one line is \(layout.singleLine)."
            )
        }
        // The category's value is drawn in the subheadline font, a line taller than the caption labels.
        let value = try #require(layout.frame(labelled: category), "No element reads \(category); \(layout.labels).")
        #expect(
            abs(value.height - layout.valueLine) <= Self.tolerance,
            "\(identifier): \(category) is \(value.height) pt tall, one line is \(layout.valueLine)."
        )
    }

    // MARK: Hosting

    /// The accessibility elements of a card, and the height of one caption-sized line in the same environment.
    private struct Laid {
        let frames: [(label: String, frame: CGRect)]
        let title: CGRect?
        let singleLine: CGFloat
        let valueLine: CGFloat

        var labels: [String] { frames.map(\.label) }

        func frame(labelled label: String) -> CGRect? {
            frames.first(where: { $0.label == label })?.frame
        }
    }

    private static func card(compact usesCompactInformation: Bool) -> GalleryCardCell {
        withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            GalleryCardCell(
                gallery: gallery, currentID: "", colors: [], showsRichInformation: true,
                usesCompactInformation: usesCompactInformation, webImageSuccessAction: { _ in }
            )
        }
    }

    private static func read(
        _ card: GalleryCardCell, width: CGFloat, identifier: String, size: DynamicTypeSize = .accessibility5
    ) throws -> Laid {
        let content = VStack(alignment: .leading, spacing: 0) {
            card.frame(width: width)
            Text(verbatim: "One line").font(.caption)
            Text(verbatim: "One value line").font(.subheadline)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.dynamicTypeSize, size)
        .environment(\.locale, Locale(identifier: identifier))
        let window = try CGSize(width: width + 40, height: max(HostedView.sceneSize().height, 2000))
        return try AccessibilityElements.read(of: content, size: window) { elements in
            let frames = elements.compactMap { element -> (label: String, frame: CGRect)? in
                guard let label = element.accessibilityLabel, !label.isEmpty else { return nil }
                return (label, element.accessibilityFrame)
            }
            let title = elements
                .first(where: { AccessibilityElements.identifier(of: $0) == "home_slideshow_title_\(gallery.id)" })?
                .accessibilityFrame
            let singleLine = try #require(frames.first(where: { $0.label == "One line" })?.frame.height)
            let valueLine = try #require(frames.first(where: { $0.label == "One value line" })?.frame.height)
            return Laid(frames: frames, title: title, singleLine: singleLine, valueLine: valueLine)
        }
    }

    // MARK: Labels

    /// The stat labels as the reader sees them in `identifier`'s language.
    private static func statLabels(identifier: String, includesRating: Bool) -> [String] {
        let resources: [LocalizedStringResource] = includesRating
            ? [.homeMetadataRating, .homeMetadataPages, .homeMetadataCategory]
            : [.homeMetadataPages, .homeMetadataCategory]
        return resources.map({ label($0, identifier) })
    }

    private static func label(_ resource: LocalizedStringResource, _ identifier: String) -> String {
        var localized = resource
        localized.locale = Locale(identifier: identifier)
        return String(localized: localized)
    }
}
