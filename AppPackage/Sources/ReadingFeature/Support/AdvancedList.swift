import SwiftUI

struct AdvancedList<Element, ID, PageView, G>: View
where PageView: View, ID: Hashable & Sendable, G: Gesture {
    /// The list's position, identified by page number.
    ///
    /// Every programmatic positioning (resume, the slider, tap-to-turn, autoplay and the accessibility page
    /// actions) aligns the target page's top with the top of the screen, while the modifier's `.center` anchor
    /// keeps choosing the page under the screen center as the current page when the user scrolls.
    ///
    /// Centering a page the lazy stack has not built yet lands on its estimated height, so the landing exposes
    /// and builds the page above it; when that page's image loads, its height changes, the scroll view keeps its
    /// offset and the target page moves (measured 2026-10-09 with placeholders that filled the screen: 324 pt on
    /// the iPhone, 43 pt on the iPad), so where a resume settles depends on the order the images load. Aligned to the
    /// top, no page above the target is on screen, and `AboveScreenHeightLock` covers the pages built above it off
    /// screen.
    ///
    /// The page model follows the page the position names whenever no scroll is under way: when a scroll comes to
    /// rest, and when the position changes outside a scroll. The status bar's scroll to the top is such a change: the
    /// position follows the page under the center, while SwiftUI reports no scroll phase for that scroll (measured
    /// 2026-10-11 on iOS 27), so the indicator and the slider follow it page by page. A programmatic position names its
    /// own page from the moment it is set: `scrollTo` raises no scroll phase, and the position keeps the requested page
    /// until the user scrolls (measured 2026-10-09 on iOS 27), so following the position after a jump names the jump's
    /// own page.
    @State private var position: ScrollPosition
    /// The phase of the scroll under way, `.idle` when none is.
    @State private var scrollPhase = ScrollPhase.idle

    private let pagerModel: PageModel
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: CGFloat
    private let gesture: G
    private let content: (Element) -> PageView

    init<Data: RandomAccessCollection>(
        page: PageModel, data: Data,
        id: KeyPath<Element, ID>, spacing: CGFloat, gesture: G,
        @ContentBuilder content: @escaping (Element) -> PageView
    ) where Data.Index == Int, Data.Element == Element {
        self.pagerModel = page
        self.data = .init(data)
        self.id = id
        self.spacing = spacing
        self.gesture = gesture
        self.content = content
        _position = State(initialValue: ScrollPosition(id: page.index + 1, anchor: .top))
    }

    var body: some View {
        // The page the position names: the page a programmatic position put at the top of the screen, or the page under
        // the center after a scroll. `isPositionedByUser`, which would leave a scrolled list without a positioned page,
        // stayed false through finger scrolls and the status bar's scroll to the top (measured 2026-10-11 on the
        // iOS 27.0 simulator).
        let positionedID = position.isPositionedByUser ? nil : position.viewID(type: ID.self)
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: spacing) {
                ForEach(data, id: id) { index in
                    content(index)
                        .modifier(AboveScreenHeightLock(isPositioned: index[keyPath: id] == positionedID))
                        .gesture(gesture)
                }
            }
            .scrollTargetLayout()
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollPosition($position, anchor: .center)
        .onScrollPhaseChange { _, newValue in
            scrollPhase = newValue
            if newValue == .idle {
                followPosition(to: position.viewID(type: Int.self))
            }
        }
        .onChange(of: position.viewID(type: Int.self)) { _, newValue in
            if scrollPhase == .idle {
                followPosition(to: newValue)
            }
        }
        .onChange(of: pagerModel.index) { _, newValue in
            tryScrollTo(id: newValue + 1)
        }
    }

    /// Writes the page the position names to the page model, unless the model already names it.
    ///
    /// A scroll coming to rest and a position change outside a scroll both call this, in either order within one
    /// update, and so does the position change that the list's own `scrollTo` makes. The check leaves every call but
    /// the first without a write, as `ReadingView.jump(toPagerIndex:)` drops a jump to the page the model names.
    private func followPosition(to id: Int?) {
        guard let id, pagerModel.index != id - 1 else { return }
        pagerModel.update(.new(index: id - 1))
    }

    /// Positions the page the model names at the top of the screen, unless the position already names it.
    ///
    /// After a write that followed the position, the position names the page already, and positioning it again would
    /// align the page under the center to the top of the screen, moving the screen the user left. The check compares
    /// the page alone, so the list never re-aligns a page its position names. No writer asks it to:
    /// `ReadingView.jump(toPagerIndex:)` drops a jump to the page the model names, and `followPosition(to:)` a write
    /// of it.
    ///
    /// No test pins the skip. An app-hosted test cannot drive a scroll the position follows, and a UI test cannot
    /// tell a page re-aligned to the top from one left where the finger stopped on both the iPhone and the iPad
    /// (measured 2026-10-11), so a change here needs a real drag that comes to rest on a new page, checked for a
    /// `scrollTo` after the write.
    private func tryScrollTo(id: Int) {
        guard position.viewID(type: Int.self) != id else { return }
        position.scrollTo(id: id, anchor: .top)
    }
}

/// Keeps a page that lies entirely above the screen at the height it had when it got there, until its top is back
/// on screen or the list's position names it.
///
/// An accessibility client, such as VoiceOver or a UI test reading the screen, makes the lazy stack build the pages
/// around the visible ones, pages entirely above the screen among them (measured 2026-10-09: a capture's first
/// accessibility query built the two pages above the resume page within 87 ms). Such a page starts as its
/// placeholder, as every image load does, and when its image arrives and changes its height, the scroll view's
/// automatic offset adjustment moves the pages on screen by an amount that depends on the order the images load in:
/// none, twice or four times the change in the measured cases (2026-10-09 on iOS 27;
/// `defaultScrollAnchor(.top, for: .sizeChanges)` changes nothing). A page that keeps its height while it lies
/// above the screen gives that adjustment nothing to act on. Its content still changes inside the kept height,
/// aligned to its top: a shorter image leaves a gap at the page's bottom, a taller image is fitted into the kept
/// height, narrower than the screen and centered, and content that keeps its own size, such as the placeholder shown
/// again while an image reloads, is clipped to it. The release then moves the pages below by the difference once.
///
/// The lock prevents the height change instead of correcting what it moves: aligning the positioned page again
/// from a geometry action after the adjustment re-places the built pages within the same update, and SwiftUI then
/// flags the geometry action as cycling (measured 2026-10-10). Engaging the lock writes the page's current height,
/// so it changes no layout. The release waits for the page's top to be on screen: releasing changes the page's
/// height, which moves its bottom edge but not its top, so the page stays in the zone that released it. Releasing
/// once only its bottom shows could shrink it back above the screen within the same update and cycle.
///
/// The page the list positions at the top of the screen never locks, and a locked page releases when the list positions
/// it: a programmatic position puts the page's top at the top of the screen, so its height change moves only the pages
/// below it, whichever pixel row its edge rounds to. The first passes of a resize can still report the positioned page
/// above the screen (measured 2026-10-10), and it does not lock there. On the iPhone, whose offsets are thirds of a
/// point, the computed edge of a page positioned on a half pixel can lie a rounding error more than half a pixel above
/// the top, where its zone alone kept the page locked (measured 2026-10-10). A user scroll that stops with a locked
/// page's top there leaves the page locked until the next scroll.
///
/// An ordinary upward scroll first builds each page while part of it already shows (measured 2026-10-10 for stepped
/// and animated scrolls), so the lock engages only for pages an accessibility client builds above the screen and for
/// built pages that leave it upwards.
///
/// Pages above the screen that take new heights in the same layout pass as a container size change, such as a rotation
/// or a Split View resize, move the pages on screen by once or twice the change (measured 2026-10-10), so the lock
/// keeps a page's old height through a resize rather than following the container's width, and the page shows narrower
/// or with a gap below it while only part of it is on screen. Keeping the position through size changes is beyond the
/// lock, though: SwiftUI lays the pages out at the new size against the old offset for one or more passes before it
/// corrects the offset, and the lock cannot tell those passes from a settled layout. A locked page whose stale frame
/// put its top on screen released there and left the positioned page's top about 460 pt above the screen on an iPhone
/// turned to landscape a second time, and after an iPad window narrowed and widened again the correction itself left it
/// 464 pt above the screen with no lock decision involved (measured 2026-10-10). A single resize from rest kept it at
/// the top. On the iPhone, SwiftUI flags the zone observation as cycling between duplicate values during a resize, as
/// the passes of one resize alternate its value, even when the lock changes no height (measured 2026-10-10). The lock
/// relies on `onGeometryChange` reporting a page's first geometry, which the reader list tests cover.
private struct AboveScreenHeightLock: ViewModifier {
    /// Whether the list's position names this page: the page a programmatic position put at the top of the screen, or
    /// the page under the center after a scroll (see `AdvancedList.body`). A locked page that becomes the page under
    /// the center therefore releases there, even while its top is still above the screen.
    let isPositioned: Bool
    @Environment(\.displayScale) private var displayScale
    @State private var lockedHeight: CGFloat?

    func body(content: Content) -> some View {
        // The geometry closure is Sendable, so it takes the scale as a value rather than reading the environment.
        let displayScale = displayScale
        content
            .frame(height: lockedHeight, alignment: .top)
            .clipped()
            .onGeometryChange(for: ScreenZone.self, of: { ScreenZone(of: $0, displayScale: displayScale) }) {
                switch $0 {
                case .above(let height):
                    if lockedHeight == nil, !isPositioned {
                        lockedHeight = height
                    }
                case .acrossTop:
                    break
                case .topOnOrBelow:
                    if lockedHeight != nil {
                        lockedHeight = nil
                    }
                }
            }
            .onChange(of: isPositioned) { _, isPositioned in
                if isPositioned, lockedHeight != nil {
                    lockedHeight = nil
                }
            }
    }
}

/// Where a page lies against the top of the scroll view's visible region, whose top excludes a top safe-area inset.
///
/// The page's edges are compared as the pixel rows they are drawn on. The lazy stack lays pages out at fractional
/// points while the scroll view moves on the pixel grid, so the page above a positioned page can reach a fraction of
/// a pixel into the screen without drawing anything there (0.071 pt after a jump across pages the stack only
/// estimated, measured 2026-10-10); compared in points, that page would count as on screen and never lock. An edge
/// exactly half a pixel between two rows goes to the row below it (`PixelGrid.row(of:displayScale:)`), so a page the
/// scroll view leaves half a pixel above the top of the screen is drawn from its first row and counts as on screen.
private enum ScreenZone: Equatable {
    /// Entirely above the screen, with the page's height.
    case above(height: CGFloat)
    /// Across the top of the screen.
    case acrossTop
    /// With its top on screen or below it.
    case topOnOrBelow

    init(of proxy: GeometryProxy, displayScale: CGFloat) {
        let frame = proxy.frame(in: .scrollView(axis: .vertical))
        self = if PixelGrid.row(of: frame.maxY, displayScale: displayScale) <= 0 {
            .above(height: frame.height)
        } else if PixelGrid.row(of: frame.minY, displayScale: displayScale) < 0 {
            .acrossTop
        } else {
            .topOnOrBelow
        }
    }
}
