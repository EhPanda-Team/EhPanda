import CoreGraphics
import Foundation

/// Sizes a page's translations at one font size for the whole page, so the page reads as one piece
/// of lettering.
///
/// The size is the largest at which every translation fits its region, never larger than the page's
/// own lettering and never smaller than a floor that stays legible once the reader scales the page.
/// A translation that does not fit at that size takes the next step that fits: 85% of it, then 85%
/// of it in its region grown by a quarter. One that fits none of them is set at that last step and
/// ends in an ellipsis, and it does not hold the page's size down. Every translation on a page is
/// therefore set at the page's size or 85% of it.
enum LiveTextTextFitter {
    static let reducedScale = 0.85
    static let grownScale = 1.25
    /// The floor, as a share of the page's width.
    static let floorShare = 0.02
    /// Halvings of the search between the floor and the page's own lettering: under a 1/4000 of their gap.
    static let searchSteps = 12

    struct Region: Equatable {
        let id: UUID
        let text: String
        /// The space the text is set in, before any growth.
        let area: CGSize
        /// The height of the lettering the translation replaces.
        let lineHeight: Double
    }

    struct Placement: Equatable {
        let id: UUID
        let fontSize: Double
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
            placement(for: region, at: fontSize, style: style)
                ?? Placement(id: region.id, fontSize: fontSize * reducedScale, isGrown: true)
        }
        return Result(fontSize: fontSize, placements: placements)
    }

    /// The first step that fits `region` when the page's size is `fontSize`, or `nil` when none does.
    private static func placement(for region: Region, at fontSize: Double, style: LiveTextTextStyle) -> Placement? {
        let steps = [
            Placement(id: region.id, fontSize: fontSize, isGrown: false),
            Placement(id: region.id, fontSize: fontSize * reducedScale, isGrown: false),
            Placement(id: region.id, fontSize: fontSize * reducedScale, isGrown: true)
        ]
        return steps.first { step in
            let area = step.isGrown
                ? CGSize(width: region.area.width * grownScale, height: region.area.height * grownScale)
                : region.area
            let layout = LiveTextTextLayout(text: region.text, style: style, fontSize: step.fontSize, width: area.width)
            return layout.height <= area.height && !layout.breaksWord
        }
    }
}
