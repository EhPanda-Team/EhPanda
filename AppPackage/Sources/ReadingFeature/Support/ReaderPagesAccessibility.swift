import AppModels
import ComposableArchitecture
import SwiftUI

/// Makes the reader's pages one accessibility element, in every reading direction (owner, 2026-10-11).
///
/// Page elements in the lazy stacks drew VoiceOver's first focus to a page built above or before the resume page,
/// and VoiceOver scrolled there as the reader opened. One element leaves VoiceOver nothing to scroll to. It reads the
/// shown pages and their position, swiping up or down turns the page, a three-finger swipe turns it as well, and the
/// shown pages' actions live here.
///
/// The pages' loading states and image URLs are read in this modifier rather than in `ReadingView.body`, so a page
/// loading updates the element and not the whole reader.
struct ReaderPagesAccessibility: ViewModifier {
    let store: StoreOf<ReadingReducer>
    let pageModel: PageModel
    let isLandscape: Bool
    /// Turns the page by the given number of positions, forward when positive.
    let turnPage: (Int) -> Void

    func body(content: Content) -> some View {
        let pages = shownPages
        content
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("reading_pages")
            .accessibilityLabel(.accessibilityPageSlider)
            .accessibilityValue(description(of: pages))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    turnPage(1)
                case .decrement:
                    turnPage(-1)
                @unknown default:
                    break
                }
            }
            .accessibilityScrollAction(scroll(toward:))
            // VoiceOver lists the actions in the order SwiftUI hands them over, which on iOS 27 is the reverse of
            // their declaration. SwiftUI documents no order, so this declares them in the context menu's order and
            // leaves the rest to SwiftUI rather than reversing them to match.
            .accessibilityActions {
                ForEach(pages, id: \.self) { page in
                    PageActions(
                        page: page,
                        naming: .numbered,
                        imageURL: store.displayImageURLs[page],
                        originalImageURL: store.displayOriginalImageURLs[page],
                        refetchAction: { store.send(.refetchImageURLs($0)) },
                        copyImageAction: { store.send(.copyImage($0)) },
                        saveImageAction: { store.send(.saveImage($0)) },
                        shareImageAction: { store.send(.shareImage($0)) }
                    )
                }
            }
    }

    /// The pages shown at the current position, in page order: one, or two in a spread.
    private var shownPages: [Int] {
        let dataSource = store.state.containerDataSource(setting: store.setting, isLandscape: isLandscape)
        guard dataSource.indices.contains(pageModel.index) else { return [] }
        let config = store.state.imageContainerConfigs(
            index: dataSource[pageModel.index],
            setting: store.setting,
            isLandscape: isLandscape
        )
        return [
            config.isFirstAvailable ? config.firstIndex : nil,
            config.isSecondAvailable ? config.secondIndex : nil
        ]
        .compactMap(\.self)
        .sorted()
    }

    private func description(of pages: [Int]) -> LocalizedStringResource {
        Self.description(
            of: pages,
            failedPages: pages.filter({ store.imageURLLoadingStates[$0]?.failed != nil }),
            total: store.gallery.pageCount
        )
    }

    /// The element's value: the position, as the slider reads it, then which shown page failed to load. A
    /// spread reads as a range, and names its failed page unless both failed.
    static func description(of pages: [Int], failedPages: [Int], total: Int) -> LocalizedStringResource {
        let position: LocalizedStringResource = if let first = pages.first, let last = pages.last, first != last {
            .accessibilityPagesOf(first: first, last: last, total: total)
        } else {
            .accessibilityPageOf(current: pages.first ?? 0, total: total)
        }
        let status: LocalizedStringResource? = if failedPages.isEmpty {
            nil
        } else if failedPages.count == pages.count {
            .accessibilityFailedToLoad
        } else {
            failedPages.first.map({ .accessibilityPageFailedToLoad(page: $0) })
        }
        guard let status else { return position }
        return .accessibilityPageStatus(String(localized: position), String(localized: status))
    }

    /// Turns the page for a VoiceOver three-finger swipe, which reaches the element instead of the scroll view inside
    /// it. `edge` is the edge the content scrolls toward (Apple's own example refreshes on `.top`), so the swipe that
    /// scrolls on to the content below, or after in the reading direction, turns forward. The new position is
    /// announced as VoiceOver announces a scroll view's page; a turn the bounds stop announces the same position
    /// again, which VoiceOver reports as the border.
    private func scroll(toward edge: Edge) {
        let step = switch (store.setting.readingDirection, edge) {
        case (.vertical, .bottom), (.leftToRight, .trailing), (.rightToLeft, .leading): 1
        case (.vertical, .top), (.leftToRight, .leading), (.rightToLeft, .trailing): -1
        default: 0
        }
        guard step != 0 else { return }
        turnPage(step)
        AccessibilityNotification.PageScrolled(String(localized: description(of: shownPages))).post()
    }
}
