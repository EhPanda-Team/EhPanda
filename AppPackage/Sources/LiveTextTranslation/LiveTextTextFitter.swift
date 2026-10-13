import CoreGraphics
import Foundation

/// Sizes a page's translations at one font size for the whole page, so the page reads as one piece
/// of lettering.
///
/// The size is the largest at which every translation fits its region, never larger than the page's
/// own lettering and never smaller than a floor that stays legible once the reader scales the page.
/// A region tries its spaces in turn: where its lettering was, or the rooms its balloon has, widest
/// first, so a translation takes as few lines as its balloon allows. A translation that fits none of
/// them at that size takes the next step that fits: 85% of it in the same spaces, then 85% of it on a
/// plate grown past them. One that fits none of them is set at the last step and ends in an ellipsis,
/// and it does not hold the page's size down. Every translation on a page is therefore set at the
/// page's size or 85% of it.
enum LiveTextTextFitter {
    static let reducedScale = 0.85
    /// How much a plate grows at most past its lettering.
    static let grownScale = 1.25
    /// The floor, as a share of the page's width.
    static let floorShare = 0.02
    /// Halvings of the search between the floor and the page's own lettering: under a 1/4000 of their gap.
    static let searchSteps = 12

    struct Region: Equatable {
        let id: UUID
        let text: String
        /// The spaces the text is set in, in the order they are tried: where its lettering was, or the
        /// rooms its balloon has.
        let areas: [CGSize]
        /// The space of a plate grown past `areas`, where the text goes when none of them holds it.
        let grownArea: CGSize
        /// The height of the lettering the translation replaces.
        let lineHeight: Double
    }

    struct Placement: Equatable {
        let id: UUID
        let fontSize: Double
        /// The space the text is set in.
        let area: CGSize
        /// Whether that is the grown plate's.
        let isGrown: Bool
    }

    struct Result: Equatable {
        /// The page's size, which no translation exceeds.
        let fontSize: Double
        let placements: [Placement]
    }

    static func fit(_ regions: [Region], style: LiveTextTextStyle, pageWidth: Double) -> Result {
        let ratio = style.lineHeightRatio
        guard let ceiling = regions.map({ $0.lineHeight / ratio }).median, ceiling > 0 else {
            return Result(fontSize: 0, placements: [])
        }
        let floor = Swift.min(ceiling, pageWidth * floorShare)
        let constraining = regions.filter({ placement(for: $0, at: floor, style: style) != nil })
        func fitsEveryRegion(at fontSize: Double) -> Bool {
            constraining.allSatisfy({ placement(for: $0, at: fontSize, style: style) != nil })
        }

        var fontSize = ceiling
        if !fitsEveryRegion(at: ceiling) {
            var fitting = floor
            var failing = ceiling
            for _ in 0..<searchSteps {
                let middle = (fitting + failing) / 2
                if fitsEveryRegion(at: middle) {
                    fitting = middle
                } else {
                    failing = middle
                }
            }
            fontSize = fitting
        }
        let placements = regions.map { region in
            let steps = steps(for: region, at: fontSize)
            return placement(for: region, at: fontSize, style: style) ?? steps[steps.index(before: steps.endIndex)]
        }
        return Result(fontSize: fontSize, placements: placements)
    }

    /// The steps `region` is tried at in turn when the page's size is `fontSize`; it takes the last of
    /// them, the grown plate, when it fits none.
    private static func steps(for region: Region, at fontSize: Double) -> [Placement] {
        let reduced = fontSize * reducedScale
        let steps = [fontSize, reduced].flatMap { size in
            region.areas.map({ Placement(id: region.id, fontSize: size, area: $0, isGrown: false) })
        }
        return steps + [Placement(id: region.id, fontSize: reduced, area: region.grownArea, isGrown: true)]
    }

    /// The first step that fits `region` when the page's size is `fontSize`, or `nil` when none does.
    private static func placement(for region: Region, at fontSize: Double, style: LiveTextTextStyle) -> Placement? {
        steps(for: region, at: fontSize).first { step in
            let layout = LiveTextTextLayout(
                text: region.text,
                style: style,
                fontSize: step.fontSize,
                width: step.area.width
            )
            return layout.height <= step.area.height && !layout.breaksWord
        }
    }
}
