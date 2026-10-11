import AppTools
import SwiftUI

/// Where the reader shows a page: in the vertical strip, or in the horizontal pager, on its own or as half of a
/// dual-page spread.
enum PageSlot: Equatable {
    case strip
    case pager(isDualPage: Bool)
}

/// A page whose image has not loaded: its background, with `content` (the page number above the load's progress or a
/// reload button) where the page is seen first. The placeholder, the placeholder shown again while the image reloads,
/// and the box shown while the image URL loads or after a load failed are all this view, so a page changes height
/// only when its image replaces it, and shows its number in one place whichever of them it shows.
///
/// The content is centered in the page's first screen: the part of the page from its top that is as tall as the
/// screen, or the whole page when the page is shorter than the screen. A page positioned at the top of the screen
/// then shows its number and progress at the center of the screen, where a page that took the screen's height showed
/// them. A strip page in landscape is about two screens tall, and centered on the page the content lay below the
/// bottom of the screen (measured 2026-10-11: 864 pt down a 1728.5 pt page on the 834 pt tall screen of an iPad). The
/// screen's height moves only the content, never the page's height, which `UnloadedPageFrame` takes from the width
/// alone. In the pager a page is its cell, so the content is centered on it.
struct UnloadedPage<Content: View>: View {
    private let slot: PageSlot
    private let backgroundColor: Color
    private let content: Content

    init(slot: PageSlot, backgroundColor: Color, @ContentBuilder content: () -> Content) {
        self.slot = slot
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        backgroundColor
            .overlay(alignment: .top) {
                ViewThatFits(in: .vertical) {
                    // The screen's height, which fits when the screen is no taller than the page: its first screen.
                    Color.clear.overlay { content }.containerRelativeFrame(.vertical)
                    // The whole page, when it is shorter than the screen.
                    Color.clear.overlay { content }
                }
            }
            .modifier(UnloadedPageFrame(slot: slot))
    }
}

/// The frame of an unloaded page (`UnloadedPage`), which every unloaded state takes.
///
/// In the strip a page takes the strip's width by the height a page of `Defaults.ImageSize.contentAspect` has at that
/// width, on the pixel grid. The height must not follow the screen's: the reader is presented at less than its final
/// height and grows to it (1052 to 1210 pt on the iPad), so pages built a moment apart took different heights, and
/// when an accessibility client built them above the resume page, the scroll view's adjustment moved that page off
/// the top of the screen in 4 of 15 VoiceOver resumes, seconds before any image loaded (measured 2026-10-11 on the
/// iOS 27 simulator). Every state takes this frame: with only the placeholder off the screen's height, the box still
/// on it moved the resume page in 15 of 15. Off the pixel grid, the pages built above left the resume page's top a
/// pixel below the top of the screen in 12 of 13 such resumes, and on the grid in none of 15.
///
/// In the pager a page takes its whole cell, half of it in a dual-page spread: the pager's offsets depend on its pages'
/// widths alone, so a height that follows the screen's moves nothing.
private struct UnloadedPageFrame: ViewModifier {
    let slot: PageSlot
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        switch slot {
        case .strip:
            StripPageLayout(aspectRatio: Defaults.ImageSize.contentAspect, displayScale: displayScale) {
                content
            }
            // Offers the layout the strip's width in every pass, a probe of the page's ideal size among them.
            .containerRelativeFrame(.horizontal)
        case .pager(let isDualPage):
            content
                .containerRelativeFrame([.horizontal, .vertical]) { length, axis in
                    axis == .horizontal ? length / (isDualPage ? 2 : 1) : length
                }
        }
    }
}

/// Sizes its content to the width it is offered by the height a page of `aspectRatio` (width over height) has at that
/// width, on the pixel grid, whatever height it is offered: a page the list keeps at an older height
/// (`AboveScreenHeightLock`) offers that height, and the page is clipped to it.
struct StripPageLayout: Layout {
    let aspectRatio: CGFloat
    let displayScale: CGFloat

    /// The height of a page `width` points wide, on the pixel grid.
    static func height(width: CGFloat, aspectRatio: CGFloat, displayScale: CGFloat) -> CGFloat {
        PixelGrid.row(of: width / aspectRatio, displayScale: displayScale) / displayScale
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // `UnloadedPageFrame` always offers a finite width; any other offer has no page size to answer with.
        guard let width = proposal.width, width.isFinite else { return .zero }
        return CGSize(
            width: width, height: Self.height(width: width, aspectRatio: aspectRatio, displayScale: displayScale)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.forEach({ $0.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size)) })
    }
}
