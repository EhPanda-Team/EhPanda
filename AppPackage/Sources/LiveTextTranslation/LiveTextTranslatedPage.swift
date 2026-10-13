import AppModels
import CoreGraphics
import Foundation

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
    /// A translation in a balloon is set in the rooms its balloon has, clear of other lettering and of
    /// the rooms given before it, so it never reaches the outline; one off a balloon is set where its
    /// lettering was. A plate grown past either grows only as far as it stays off lettering it was not
    /// already over.
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
        var claimedRooms = [LiveTextOrientedRect]()
        for (id, geometry) in geometries {
            guard let text = translations[id]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  text.compare(sources[id] ?? "", options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
            else {
                continue
            }
            let lettering = geometry.letteringArea
            let otherLettering = geometries.filter({ $0.id != id }).map({ $0.geometry.letteringArea })
            let balloon = finder?.balloon(around: geometry.textRect, margin: plateMargin * geometry.lineHeight)
            let rooms = balloon?.rooms(
                around: lettering,
                lineHeight: geometry.lineHeight,
                padding: LiveTextBalloon.padding * geometry.lineHeight,
                avoiding: otherLettering + claimedRooms
            ) ?? []
            claimedRooms += rooms.map { room in
                LiveTextOrientedRect(center: lettering.center, size: room, angle: lettering.angle)
            }
            translated.append(TranslatedGroup(
                id: id,
                text: text,
                geometry: geometry,
                balloon: rooms.isEmpty ? nil : balloon,
                rooms: rooms,
                plateGrowth: Self.plateGrowth(of: geometry, avoiding: otherLettering)
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
    /// The balloon the group's lettering sits in, when it has room for a translation.
    let balloon: LiveTextBalloon?
    /// The rooms the balloon has for the translation, widest first.
    let rooms: [CGSize]
    /// How much the text area grows on a plate.
    let plateGrowth: Double

    var region: LiveTextTextFitter.Region {
        let area = geometry.letteringArea.size
        var grownArea = CGSize(width: area.width * plateGrowth, height: area.height * plateGrowth)
        // A plate past a balloon is no smaller than the balloon's largest room.
        if let largestRoom = rooms.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            grownArea.width = Swift.max(grownArea.width, largestRoom.width)
            grownArea.height = Swift.max(grownArea.height, largestRoom.height)
        }
        return LiveTextTextFitter.Region(
            id: id,
            text: text,
            areas: rooms.isEmpty ? [area] : rooms,
            grownArea: grownArea,
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
        let textArea = LiveTextOrientedRect(
            center: lettering.center,
            size: placement.area,
            angle: lettering.angle
        )
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
            fill: fill(around: plate, at: placement, bitmap: bitmap),
            shadowRadius: LiveTextTranslatedPage.shadowRadius * lineHeight,
            text: text,
            fontSize: placement.fontSize,
            isTruncated: layout.isTruncated
        )
    }

    /// The lettering painted out when the translation sits in its balloon; otherwise the plate's
    /// surroundings tell its paint.
    private func fill(
        around plate: LiveTextOrientedRect,
        at placement: LiveTextTextFitter.Placement,
        bitmap: LiveTextPageBitmap?
    ) -> LiveTextFill {
        if let balloon, !placement.isGrown, let paint = balloon.paint() {
            return .balloon(paint, text: balloon.textColor)
        }
        guard let bitmap else {
            return .plate
        }
        return LiveTextPlateSampler.fill(around: plate, lineHeight: geometry.lineHeight, on: bitmap)
    }
}
