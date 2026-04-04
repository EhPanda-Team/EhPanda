//
//  AdvancedList.swift
//  EhPanda
//

import SwiftUI
import SwiftUIPager

struct AdvancedList<Element, ID, PageView, G>: View
where PageView: View, Element: Equatable, ID: Hashable, G: Gesture {
    @State var performingChanges = false
    @State var scrollPositionID: Int?

    private let pagerModel: Page
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: CGFloat
    private let gesture: G
    private let content: (Element) -> PageView

    init<Data: RandomAccessCollection>(
        page: Page, data: Data,
        id: KeyPath<Element, ID>, spacing: CGFloat, gesture: G,
        @ViewBuilder content: @escaping (Element) -> PageView
    ) where Data.Index == Int, Data.Element == Element {
        self.pagerModel = page
        self.data = .init(data)
        self.id = id
        self.spacing = spacing
        self.gesture = gesture
        self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: spacing) {
                    ForEach(data, id: id) { index in
                        content(index)
                            .gesture(gesture)
                    }
                }
                .scrollTargetLayout()
                .onAppear(perform: { tryScrollTo(id: pagerModel.index + 1, proxy: proxy) })
            }
            .scrollPosition(id: $scrollPositionID, anchor: .center)
            .modifier(ScrollPhaseChangeModifier(
                scrollPositionID: $scrollPositionID,
                performingChanges: $performingChanges,
                pagerModel: pagerModel
            ))
            .onChange(of: pagerModel.index) { _, newValue in
                tryScrollTo(id: newValue + 1, proxy: proxy)
            }
        }
    }

    private func tryScrollTo(id: Int, proxy: ScrollViewProxy) {
        if !performingChanges {
            scrollPositionID = id
        }
    }
}

// MARK: ScrollPhaseChangeModifier
private struct ScrollPhaseChangeModifier: ViewModifier {
    @Binding var scrollPositionID: Int?
    @Binding var performingChanges: Bool
    let pagerModel: Page
    @State private var lastScrollPositionID: Int?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollPhaseChange { _, newValue in
                    if newValue == .idle, let index = scrollPositionID {
                        performingChanges = true
                        pagerModel.update(.new(index: index - 1))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            performingChanges = false
                        }
                    }
                }
        } else {
            content
                .onChange(of: scrollPositionID) { _, newValue in
                    if let index = newValue, index != lastScrollPositionID {
                        lastScrollPositionID = index
                        // Use a small delay to detect when scrolling has stopped
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Check if scroll position is still the same (scrolling stopped)
                            if scrollPositionID == index {
                                performingChanges = true
                                pagerModel.update(.new(index: index - 1))
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    performingChanges = false
                                }
                            }
                        }
                    }
                }
        }
    }
}
