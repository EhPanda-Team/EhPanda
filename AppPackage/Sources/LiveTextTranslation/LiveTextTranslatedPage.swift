import AppModels
import CoreGraphics
import Foundation

/// A page's translations, laid out over the regions they replace.
public struct LiveTextTranslatedPage: Equatable, Sendable {
    /// One recognized group, painted over and showing its translation.
    public struct Group: Equatable, Identifiable, Sendable {
        public let id: UUID
        /// The painted region.
        public let plate: LiveTextOrientedRect
        public let cornerRadius: Double
        /// Where the translation is set, inside the plate.
        public let textArea: LiveTextOrientedRect
        /// The width the translation's lines are set at, centered in ``textArea``: the narrowest that
        /// keeps their number, so they come out even.
        public let lineWidth: Double
        public let fill: LiveTextFill
        /// The blur of a plate's shadow, in page pixels.
        public let shadowRadius: Double
        public let text: String
        public let fontSize: Double
        /// Whether the translation did not fit even its grown region and ends in an ellipsis.
        public let isTruncated: Bool
    }

    /// Text area and plate margins, and the plate's corner radius and shadow, in line heights of the
    /// lettering they replace.
    static let textMargin = 0.15
    static let plateMargin = 0.3
    static let cornerRadius = 0.35
    static let shadowRadius = 0.4

    /// The page image's size in pixels, the space everything here is measured in.
    public let pageSize: CGSize
    /// The language the page is translated into.
    public let language: Locale.Language
    /// The page's font size; every group is set at it or 85% of it.
    public let fontSize: Double
    public let groups: [Group]

    /// Lays out `translations` over the groups of `image` they translate.
    ///
    /// A group without a translation, or whose translation reads as its source (`sources`), as a name
    /// or a sound effect often does, keeps its lettering and is left out.
    public static func layOut(
        groups: [LiveTextGroup],
        sources: [UUID: String],
        translations: [UUID: String],
        language: Locale.Language,
        image: CGImage
    ) -> Self {
        let pageSize = CGSize(width: image.width, height: image.height)
        let style = LiveTextTextStyle(language: language)
        let translated = groups.compactMap { group -> TranslatedGroup? in
            guard let text = translations[group.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  text.compare(
                      sources[group.id] ?? "",
                      options: [.caseInsensitive, .diacriticInsensitive]
                  ) != .orderedSame,
                  let geometry = LiveTextGroupGeometry(group: group, pageSize: pageSize)
            else {
                return nil
            }
            return TranslatedGroup(id: group.id, text: text, geometry: geometry)
        }
        let fitting = LiveTextTextFitter.fit(
            translated.map(\.region),
            style: style,
            pageWidth: pageSize.width
        )
        let placements = Dictionary(fitting.placements.map({ ($0.id, $0) }), uniquingKeysWith: { first, _ in first })
        let bitmap = LiveTextPageBitmap(image: image)
        return Self(
            pageSize: pageSize,
            language: language,
            fontSize: fitting.fontSize,
            groups: translated.compactMap { group in
                placements[group.id].map({ group.laidOut(at: $0, style: style, bitmap: bitmap) })
            }
        )
    }
}

private struct TranslatedGroup {
    let id: UUID
    let text: String
    let geometry: LiveTextGroupGeometry

    var region: LiveTextTextFitter.Region {
        LiveTextTextFitter.Region(
            id: id,
            text: text,
            area: geometry.textRect.expanded(by: LiveTextTranslatedPage.textMargin * geometry.lineHeight).size,
            lineHeight: geometry.lineHeight
        )
    }

    func laidOut(
        at placement: LiveTextTextFitter.Placement,
        style: LiveTextTextStyle,
        bitmap: LiveTextPageBitmap?
    ) -> LiveTextTranslatedPage.Group {
        let lineHeight = geometry.lineHeight
        let textMargin = LiveTextTranslatedPage.textMargin * lineHeight
        let plateMargin = LiveTextTranslatedPage.plateMargin * lineHeight
        let growth = placement.isGrown ? LiveTextTextFitter.grownScale : 1
        let textArea = geometry.textRect
            .expanded(by: textMargin)
            .scaled(by: growth)
        let plate = textArea.expanded(by: plateMargin - textMargin)
        let layout = LiveTextTextLayout(
            text: text,
            style: style,
            fontSize: placement.fontSize,
            width: textArea.size.width,
            maximumHeight: textArea.size.height
        )
        // A truncated translation needs every bit of its width.
        let lineWidth = layout.isTruncated
            ? textArea.size.width
            : LiveTextTextLayout.balancedWidth(
                of: text,
                style: style,
                fontSize: placement.fontSize,
                width: textArea.size.width
            )
        return LiveTextTranslatedPage.Group(
            id: id,
            plate: plate,
            cornerRadius: Swift.min(
                LiveTextTranslatedPage.cornerRadius * lineHeight,
                Swift.min(plate.size.width, plate.size.height) / 2
            ),
            textArea: textArea,
            lineWidth: lineWidth,
            fill: bitmap.map({ LiveTextPlateSampler.fill(around: plate, lineHeight: lineHeight, on: $0) }) ?? .plate,
            shadowRadius: LiveTextTranslatedPage.shadowRadius * lineHeight,
            text: text,
            fontSize: placement.fontSize,
            isTruncated: layout.isTruncated
        )
    }
}
