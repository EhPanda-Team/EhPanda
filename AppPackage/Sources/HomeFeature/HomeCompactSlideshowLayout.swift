import SwiftUI

/// Arranges the compact slideshow card: the cover, the title, the stats and, when the gallery has tags, the tags.
///
/// The subviews are, in order, the cover, the title, the stats and the optional tags, which is also the order
/// VoiceOver reads them in. Beside the cover the title sits at the top of the text column, the stats and the tags at
/// its bottom, as one column exactly the cover's height. In the ``Arrangement/below`` arrangement the stats leave the
/// column and sit under the cover at the card's full width, so the card grows by the height of the stats and the
/// space before them.
///
/// The owner's C9 decision (19-23): no stat label is ever broken mid-word. A label beside the cover has only the
/// text column to live in, 176 pt on the iPhone in portrait, and "Bewertung" alone is wider than that at the largest
/// accessibility size, so no arrangement of the stats inside the column can keep every label whole. The stats have to
/// leave the column, which only the card can do: a stat view cannot place itself under its sibling cover. That is why
/// this is a layout of the whole card rather than a `ViewThatFits` of alternative stat grids.
///
/// The choice between the arrangements is made by the card (`HomeCompactSlideshowContent`), as a `ViewThatFits` over
/// one layout of each arrangement, and it compares the stats against the text column, not the title. A `ViewThatFits`
/// takes an option whose ideal width is at most the proposed width, and a title's ideal width is its whole text on one
/// line, which would reject every arrangement. So the ideal width of ``Arrangement/beside`` is the cover, its spacing
/// and the narrowest the stats get (the two-column grid, which the stats report for a proposal of zero width). The
/// tags are dropped, as before, when they do not fit under the title and the stats in the cover's height: the tags
/// view itself (`HomeCompactSlideshowTags`) shows nothing in a proposal that is too short, and this layout proposes
/// that when the tags do not fit.
struct HomeCompactSlideshowLayout: Layout {
    enum Arrangement {
        case beside
        case below
    }

    let arrangement: Arrangement

    private static let coverSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = placement(width: bounds.width, subviews: subviews)
        for (subview, placed) in zip(subviews, plan.placed) {
            subview.place(
                at: CGPoint(x: bounds.minX + placed.origin.x, y: bounds.minY + placed.origin.y),
                proposal: placed.proposal
            )
        }
    }

    private struct Placed {
        var origin: CGPoint
        var proposal: ProposedViewSize
    }

    private struct Placement {
        var size: CGSize
        var placed: [Placed]
    }

    private func placement(width proposedWidth: CGFloat?, subviews: Subviews) -> Placement {
        guard let cover = subviews.first,
              let title = subviews.dropFirst().first,
              let stats = subviews.dropFirst(2).first
        else { return Placement(size: .zero, placed: []) }
        let tags = subviews.dropFirst(3).first

        let coverSize = cover.sizeThatFits(.unspecified)
        let textOffset = coverSize.width + Self.coverSpacing
        let narrowestStats = stats.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
        let width = proposedWidth ?? textOffset + (arrangement == .beside ? narrowestStats : 0)
        let columnWidth = max(0, width - textOffset)
        let column = ProposedViewSize(width: columnWidth, height: nil)

        let titleHeight = title.sizeThatFits(column).height
        let tagsHeight = tags?.sizeThatFits(column).height
        let statsWidth = arrangement == .beside ? columnWidth : width
        let statsHeight = stats.sizeThatFits(ProposedViewSize(width: statsWidth, height: nil)).height

        let columnBottom = coverSize.height
        let reserved = arrangement == .beside ? statsHeight + Self.rowSpacing : 0
        let tagsFit = tagsHeight.map({ titleHeight + Self.rowSpacing + reserved + $0 <= columnBottom }) ?? false

        let tagsTop = columnBottom - (tagsHeight ?? 0)
        let titleBottom = (tagsFit ? tagsTop : columnBottom) - (tagsFit ? Self.rowSpacing : 0)
        let statsTop = arrangement == .beside
            ? max(0, (tagsFit ? tagsTop - Self.rowSpacing : columnBottom) - statsHeight)
            : columnBottom + Self.rowSpacing
        let titleLimit = arrangement == .beside ? max(0, statsTop - Self.rowSpacing) : titleBottom

        var placed = [
            Placed(origin: .zero, proposal: ProposedViewSize(coverSize)),
            Placed(
                origin: CGPoint(x: textOffset, y: 0),
                proposal: ProposedViewSize(width: columnWidth, height: tagsFit ? titleHeight : titleLimit)
            ),
            Placed(
                origin: CGPoint(x: arrangement == .beside ? textOffset : 0, y: statsTop),
                proposal: ProposedViewSize(width: statsWidth, height: statsHeight)
            )
        ]
        if tags != nil {
            // A proposal too short for the tags makes their `ViewThatFits` show nothing.
            placed.append(Placed(
                origin: CGPoint(x: textOffset, y: tagsFit ? tagsTop : columnBottom),
                proposal: ProposedViewSize(width: columnWidth, height: tagsFit ? tagsHeight : 0)
            ))
        }
        let height = arrangement == .beside ? columnBottom : statsTop + statsHeight
        return Placement(size: CGSize(width: width, height: height), placed: placed)
    }
}
