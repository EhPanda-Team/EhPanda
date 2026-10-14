public import AppModels
public import CoreGraphics
public import Foundation

/// A page's translations, laid out over the regions they replace.
public struct LiveTextTranslatedPage: Equatable, Sendable {
    /// One recognized group, painted over and showing its translation.
    public struct Group: Equatable, Identifiable, Sendable {
        public let id: UUID
        /// The region around the translation: painted, unless the translation sits in its balloon, and
        /// ringed when the group has focus.
        public let plate: LiveTextOrientedRect
        public let cornerRadius: Double
        /// Where the translation is set, inside the plate.
        public let textArea: LiveTextOrientedRect
        /// The width each of the translation's lines is set at in turn, centered in ``textArea``: the
        /// narrowest that keep their number, so they come out even; lines past the last take it.
        public let lineWidths: [Double]
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
    /// Halvings of the search for how far a plate grows: under a 1/1000 of its growth.
    private static let growthSteps = 8

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
    ///
    /// A translation in a balloon is set in the room its balloon has, its lines following the
    /// balloon's shape, clear of its outline and of the share of the balloon other lettering in it
    /// has; one off a balloon is set where its lettering was. A plate grown past either grows only as
    /// far as it stays off lettering it was not already over.
    public static func layOut(
        groups: [LiveTextGroup],
        sources: [UUID: String],
        translations: [UUID: String],
        language: Locale.Language,
        image: CGImage
    ) -> Self {
        let pageSize = CGSize(width: image.width, height: image.height)
        let style = LiveTextTextStyle(language: language)
        let bitmap = LiveTextPageBitmap(image: image)
        var finder = bitmap.map(LiveTextBalloonFinder.init)
        let geometries = groups.compactMap { group in
            LiveTextGroupGeometry(group: group, pageSize: pageSize).map({ (id: group.id, geometry: $0) })
        }
        var translated = [TranslatedGroup]()
        for (id, geometry) in geometries {
            guard let text = translations[id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  text.compare(sources[id] ?? "", options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
            else {
                continue
            }
            let others = geometries.filter({ $0.id != id }).map(\.geometry)
            let balloon = finder?.balloon(
                around: geometry.textRect,
                lineHeight: geometry.lineHeight,
                among: others.map(\.textRect)
            )
            translated.append(TranslatedGroup(
                id: id,
                text: text,
                geometry: geometry,
                balloon: balloon,
                shape: balloon.map({ .balloon($0.room()) }) ?? .rectangle(geometry.letteringArea.size),
                plateGrowth: Self.plateGrowth(of: geometry, avoiding: others.map(\.letteringArea))
            ))
        }
        let fitting = LiveTextTextFitter.fit(
            translated.map(\.region),
            style: style,
            pageWidth: pageSize.width
        )
        let placements = Dictionary(fitting.placements.map({ ($0.id, $0) }), uniquingKeysWith: { first, _ in first })
        return Self(
            pageSize: pageSize,
            language: language,
            fontSize: fitting.fontSize,
            groups: translated.compactMap { group in
                placements[group.id].map({ group.laidOut(at: $0, style: style, bitmap: bitmap) })
            }
        )
    }

    /// How much, up to ``LiveTextTextFitter/grownScale``, the text area of the group `geometry` places
    /// grows on a plate before the plate reaches lettering in `others` it was not already over.
    private static func plateGrowth(
        of geometry: LiveTextGroupGeometry,
        avoiding others: [LiveTextOrientedRect]
    ) -> Double {
        let lettering = geometry.letteringArea
        let margin = (plateMargin - textMargin) * geometry.lineHeight
        func plateBounds(_ growth: Double) -> CGRect {
            lettering.scaled(by: growth).expanded(by: margin).boundingBox
        }
        let clear = others.map(\.boundingBox).filter({ !$0.intersects(plateBounds(1)) })
        func isClear(_ growth: Double) -> Bool {
            !clear.contains(where: { $0.intersects(plateBounds(growth)) })
        }
        guard !isClear(LiveTextTextFitter.grownScale) else {
            return LiveTextTextFitter.grownScale
        }
        var fitting = 1.0
        var failing = LiveTextTextFitter.grownScale
        for _ in 0..<growthSteps {
            let middle = (fitting + failing) / 2
            if isClear(middle) {
                fitting = middle
            } else {
                failing = middle
            }
        }
        return fitting
    }
}

extension LiveTextGroupGeometry {
    /// Where a translation is set when it fits where the group's lettering was.
    var letteringArea: LiveTextOrientedRect {
        textRect.expanded(by: LiveTextTranslatedPage.textMargin * lineHeight)
    }
}

private struct TranslatedGroup {
    let id: UUID
    let text: String
    let geometry: LiveTextGroupGeometry
    /// The balloon the group's lettering sits in, if any.
    let balloon: LiveTextBalloon?
    /// Where the translation is set: the room its balloon has, or where its lettering was.
    let shape: LiveTextTextShape
    /// How much the text area grows on a plate.
    let plateGrowth: Double

    var region: LiveTextTextFitter.Region {
        let area = geometry.letteringArea.size
        return LiveTextTextFitter.Region(
            id: id,
            text: text,
            shape: shape,
            grownArea: CGSize(width: area.width * plateGrowth, height: area.height * plateGrowth),
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
        let lettering = geometry.letteringArea
        let setting = placement.setting
        let textArea = LiveTextOrientedRect(
            center: setting.center.applying(lettering.transform),
            size: setting.area,
            angle: lettering.angle
        )
        let plate = textArea.expanded(by: plateMargin - textMargin)
        let layout = LiveTextTextLayout(
            text: text,
            style: style,
            fontSize: placement.fontSize,
            widths: setting.lineWidths,
            maximumHeight: textArea.size.height
        )
        // A truncated translation needs every bit of its widths.
        let lineWidths = layout.isTruncated
            ? setting.lineWidths
            : LiveTextTextLayout.balancedWidths(
                of: text,
                style: style,
                fontSize: placement.fontSize,
                widths: setting.lineWidths
            )
        return LiveTextTranslatedPage.Group(
            id: id,
            plate: plate,
            cornerRadius: Swift.min(
                LiveTextTranslatedPage.cornerRadius * lineHeight,
                Swift.min(plate.size.width, plate.size.height) / 2
            ),
            textArea: textArea,
            lineWidths: lineWidths,
            fill: fill(around: plate, clearing: textArea, at: placement, bitmap: bitmap),
            shadowRadius: LiveTextTranslatedPage.shadowRadius * lineHeight,
            text: text,
            fontSize: placement.fontSize,
            isTruncated: layout.isTruncated
        )
    }

    /// The lettering painted out, with the specks under the translation in `textArea`, when the
    /// translation sits in its balloon; otherwise the plate's surroundings tell its paint.
    private func fill(
        around plate: LiveTextOrientedRect,
        clearing textArea: LiveTextOrientedRect,
        at placement: LiveTextTextFitter.Placement,
        bitmap: LiveTextPageBitmap?
    ) -> LiveTextFill {
        if let balloon, !placement.isGrown, let paint = balloon.paint(clearing: textArea) {
            return .balloon(paint, text: balloon.textColor)
        }
        guard let bitmap else {
            return .plate
        }
        return LiveTextPlateSampler.fill(around: plate, lineHeight: geometry.lineHeight, on: bitmap)
    }
}
