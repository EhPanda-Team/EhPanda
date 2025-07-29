//
//  AdvancedList.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/30.
//  Improved architecture by zackie on 2025-07-28.
//

import SwiftUI
import SwiftUIPager

/// Improved vertical list for reading view with iOS 26 scrolling fix
struct AdvancedList<Element, ID, PageView, G>: View
where PageView: View, Element: Equatable, ID: Hashable, G: Gesture {
    
    // MARK: - State
    @State private var performingChanges = false
    @State private var scrollTarget: Element?
    
    // MARK: - Properties
    private let pagerModel: Page
    private let data: [Element]
    private let id: KeyPath<Element, ID>
    private let spacing: CGFloat
    private let gesture: G
    private let content: (Element) -> PageView
    
    // MARK: - Initialization
    init<Data: RandomAccessCollection>(
        page: Page, 
        data: Data,
        id: KeyPath<Element, ID>, 
        spacing: CGFloat, 
        gesture: G,
        @ViewBuilder content: @escaping (Element) -> PageView
    ) where Data.Index == Int, Data.Element == Element {
        self.pagerModel = page
        self.data = .init(data)
        self.id = id
        self.spacing = spacing
        self.gesture = gesture
        self.content = content
    }
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: spacing) {
                    ForEach(data, id: id) { element in
                        contentWithGestures(for: element)
                            .id(element[keyPath: id])
                    }
                }
                .onAppear {
                    initialScrollToPage(proxy: proxy)
                }
            }
            // iOS 26 compatible scroll handling
            .coordinateSpace(name: "ScrollView")
            .onChange(of: pagerModel.index) { _, newValue in
                handlePageChange(newValue: newValue, proxy: proxy)
            }
            .onChange(of: scrollTarget) { _, newValue in
                if let target = newValue {
                    scrollToTarget(target, proxy: proxy)
                }
            }
        }
    }
    
    // MARK: - Content with Gestures
    @ViewBuilder
    private func contentWithGestures(for element: Element) -> some View {
        let longPress = createLongPressGesture(for: element)
        let combinedGestures = longPress.simultaneously(with: gesture)
        
        content(element)
            .gesture(combinedGestures)
    }
    
    // MARK: - Gesture Creation
    private func createLongPressGesture(for element: Element) -> some Gesture {
        LongPressGesture(minimumDuration: 0, maximumDistance: .infinity)
            .onEnded { _ in
                handleLongPress(for: element)
            }
    }
    
    // MARK: - Event Handlers
    private func handleLongPress(for element: Element) {
        guard let index = element as? Int else { return }
        
        Logger.info("Long press detected", context: ["element": index])
        
        performingChanges = true
        pagerModel.update(.new(index: index - 1))
        
        // Reset performing changes after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            performingChanges = false
        }
    }
    
    private func initialScrollToPage(proxy: ScrollViewProxy) {
        guard !data.isEmpty else { return }
        
        let targetElement = getElementForPageIndex(pagerModel.index)
        scrollToElementSafely(targetElement, proxy: proxy, animated: false)
    }
    
    private func handlePageChange(newValue: Int, proxy: ScrollViewProxy) {
        guard !performingChanges else { return }
        
        Logger.info("Page changed in AdvancedList", context: [
            "newPageIndex": newValue,
            "dataCount": data.count
        ])
        
        let targetElement = getElementForPageIndex(newValue)
        scrollToElementSafely(targetElement, proxy: proxy, animated: true)
    }
    
    private func scrollToTarget(_ target: Element, proxy: ScrollViewProxy) {
        scrollToElementSafely(target, proxy: proxy, animated: true)
        scrollTarget = nil
    }
    
    // MARK: - Helper Methods
    private func getElementForPageIndex(_ pageIndex: Int) -> Element? {
        let safeIndex = max(0, min(pageIndex, data.count - 1))
        guard safeIndex < data.count else { return nil }
        return data[safeIndex]
    }
    
    private func scrollToElementSafely(
        _ element: Element?, 
        proxy: ScrollViewProxy, 
        animated: Bool
    ) {
        guard let element = element else { return }
        
        let elementId = element[keyPath: id]
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(elementId, anchor: .center)
            }
        } else {
            // Use dispatchMainSync for immediate scrolling without animation
            AppUtil.dispatchMainSync {
                proxy.scrollTo(elementId, anchor: .center)
            }
        }
        
        Logger.info("Scrolled to element", context: [
            "elementId": "\(elementId)",
            "animated": animated
        ])
    }
}

// MARK: - iOS 26 Compatibility Extensions

extension AdvancedList {
    /// Creates a version with enhanced scroll compatibility
    func withEnhancedScrolling() -> some View {
        self
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
    }
    
    /// Handles scroll position restoration for iOS 26
    func withScrollRestoration() -> some View {
        self
            .onAppear {
                // Ensure proper scroll position on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let currentElement = getElementForPageIndex(pagerModel.index) {
                        scrollTarget = currentElement
                    }
                }
            }
    }
}

// MARK: - Preview
struct AdvancedList_Previews: PreviewProvider {
    static var previews: some View {
        let page = Page.first()
        let sampleData = Array(1...10)
        
        AdvancedList(
            page: page,
            data: sampleData,
            id: \.self,
            spacing: 10,
            gesture: TapGesture()
        ) { item in
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 200)
                .overlay(
                    Text("\(item)")
                        .font(.title)
                        .foregroundColor(.primary)
                )
        }
        .previewLayout(.sizeThatFits)
    }
}

