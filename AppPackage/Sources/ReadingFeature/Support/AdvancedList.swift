import SwiftUI

struct AdvancedList<Element, ID, PageView, G>: View
where PageView: View, Element: Equatable, ID: Hashable, G: Gesture {
    @State var performingChanges = false
    @State var scrollPositionID: Int?

    private let pagerModel: PageModel
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: CGFloat
    private let gesture: G
    private let content: (Element) -> PageView

    init<Data: RandomAccessCollection>(
        page: PageModel, data: Data,
        id: KeyPath<Element, ID>, spacing: CGFloat, gesture: G,
        @ViewBuilder content: @escaping (Element) -> PageView
    ) where Data.Index == Int, Data.Element == Element {
        self.pagerModel = page
        self.data = .init(data)
        self.id = id
        self.spacing = spacing
        self.gesture = gesture
        self.content = content
        _scrollPositionID = State(initialValue: page.index + 1)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: spacing) {
                ForEach(data, id: id) { index in
                    content(index)
                        .gesture(gesture)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPositionID, anchor: .center)
        .onScrollPhaseChange { _, newValue in
            if newValue == .idle, let index = scrollPositionID {
                performingChanges = true
                pagerModel.update(.new(index: index - 1))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    performingChanges = false
                }
            }
        }
        .onChange(of: pagerModel.index) { _, newValue in
            tryScrollTo(id: newValue + 1)
        }
    }

    private func tryScrollTo(id: Int) {
        if !performingChanges {
            scrollPositionID = id
        }
    }
}
