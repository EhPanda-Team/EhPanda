import CoreGraphics
import Foundation

/// Sizes a page's translations at one font size for the whole page, so the page reads as one piece
/// of lettering.
///
/// The size is the largest at which every translation fits its region, never larger than the page's
/// own lettering and never smaller than a floor that stays legible once the reader scales the page.
/// A translation that does not fit at that size takes the next step that fits: 85% of it, then 85%
/// of it in the room it grows into, and for one in a balloon, past the balloon onto a plate. One that
/// fits none of them is set at the last step and ends in an ellipsis, and it does not hold the page's
/// size down. Every translation on a page is therefore set at the page's size or 85% of it.
enum LiveTextTextFitter {
    static let reducedScale = 0.85
    /// How much a region off a balloon, or one spilling past its balloon, grows at most.
    static let grownScale = 1.25
    /// The floor, as a share of the page's width.
    static let floorShare = 0.02
    /// Halvings of the search between the floor and the page's own lettering: under a 1/4000 of their gap.
    static let searchSteps = 12

    struct Region: Equatable {
        let id: UUID
        let text: String
        /// The space the text is set in, where its lettering was.
        let area: CGSize
        /// The space the text grows into when `area` is not enough: its balloon's room, or off a balloon,
        /// `area` grown by up to a quarter.
        let grownArea: CGSize
        /// The space past its balloon, on a plate, the text spills into when the balloon's room is not
        /// enough either; `nil` off a balloon.
        let spilledArea: CGSize?
        /// The height of the lettering the translation replaces.
        let lineHeight: Double

        func area(for room: Room) -> CGSize {
            switch room {
            case .lettering:
                area
            case .grown:
                grownArea
            case .spilled:
                spilledArea ?? grownArea
            }
        }
    }

    /// Where a translation is set.
    enum Room: Equatable {
        /// Where its lettering was.
        case lettering
        /// In the room it grows into.
        case grown
        /// Past its balloon, on a plate.
        case spilled
    }

    struct Placement: Equatable {
        let id: UUID
        let fontSize: Double
        let room: Room
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
    /// them when it fits none.
    private static func steps(for region: Region, at fontSize: Double) -> [Placement] {
        let reduced = fontSize * reducedScale
        let steps = [
            Placement(id: region.id, fontSize: fontSize, room: .lettering),
            Placement(id: region.id, fontSize: reduced, room: .lettering),
            Placement(id: region.id, fontSize: reduced, room: .grown)
        ]
        guard region.spilledArea != nil else {
            return steps
        }
        return steps + [Placement(id: region.id, fontSize: reduced, room: .spilled)]
    }

    /// The first step that fits `region` when the page's size is `fontSize`, or `nil` when none does.
    private static func placement(for region: Region, at fontSize: Double, style: LiveTextTextStyle) -> Placement? {
        steps(for: region, at: fontSize).first { step in
            let area = region.area(for: step.room)
            let layout = LiveTextTextLayout(text: region.text, style: style, fontSize: step.fontSize, width: area.width)
            return layout.height <= area.height && !layout.breaksWord
        }
    }
}
