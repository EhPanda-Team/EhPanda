import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import SwiftUI
import Testing
import UIKit

/// The App Activity Logs page keeps its large title while it has no logs to show.
///
/// The list was revealed with `revealed(!displayedLogs.isEmpty)`, and the cover `revealed(_:)` lays over its content
/// fills the whole container, safe area included. For a page with nothing logged that cover never lifted, and it hid
/// the large navigation title along with the empty list (the owner's C2 item, 19-13: the empty page in portrait shows
/// no title). The cover is for content that is hidden as a whole while it loads, so the page now keys it to loading.
@MainActor
struct ActivityLogsTitleTests {
    private static let pageTitle = "App Activity Logs"
    private static let portrait = CGSize(width: 390, height: 844)

    @Test
    func anEmptyLoadedPageDrawsItsTitle() throws {
        try AccessibilityElements.read(of: Self.page(loadingState: .idle), size: Self.portrait) { elements in
            let title = try #require(
                elements.first(where: { $0.accessibilityLabel == Self.pageTitle && $0.accessibilityFrame.height > 0 }),
                "The page has no element labelled \(Self.pageTitle)."
            )
            let root = try #require(elements.first as? UIView, "The first element is not the hosted root view.")
            let frame = try #require(root.window?.screen.coordinateSpace.convert(title.accessibilityFrame, to: root))
            let colours = Self.colourCount(in: frame, of: root)
            #expect(colours > 1, "The title's frame \(frame) holds \(colours) colour(s); the title is not drawn.")
        }
    }

    @Test
    func aLoadingPageShowsItsLoadingView() throws {
        try AccessibilityElements.read(of: Self.page(loadingState: .loading), size: Self.portrait) { elements in
            #expect(
                elements.contains(where: { $0.accessibilityLabel?.contains("Loading") == true }),
                "The loading view is not among the page's accessibility elements."
            )
        }
    }

    /// An Activity Logs page with no logs, in a navigation stack at the large title, in the given loading state.
    private static func page(loadingState: LoadingState) -> some View {
        let store = withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            var state = AppActivityLogsReducer.State()
            state.loadingState = loadingState
            return Store(initialState: state, reducer: AppActivityLogsReducer.init)
        }
        return NavigationStack {
            AppActivityLogsView(store: store)
        }
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// How many different colours the root view draws inside `frame`: one for an empty cover, many for drawn text.
    private static func colourCount(in frame: CGRect, of root: UIView) -> Int {
        let renderer = UIGraphicsImageRenderer(bounds: root.bounds)
        let image = renderer.image { _ in
            root.drawHierarchy(in: root.bounds, afterScreenUpdates: true)
        }
        let scale = image.scale
        let crop = CGRect(
            x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale
        )
        guard let cropped = image.cgImage?.cropping(to: crop),
              let data = cropped.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return 0 }
        let bytesPerPixel = cropped.bitsPerPixel / 8
        var colours = Set<UInt32>()
        for row in 0..<cropped.height {
            for column in 0..<cropped.width {
                let offset = row * cropped.bytesPerRow + column * bytesPerPixel
                var value: UInt32 = 0
                for channel in 0..<min(bytesPerPixel, 4) {
                    value = value << 8 | UInt32(bytes[offset + channel])
                }
                colours.insert(value)
            }
        }
        return colours.count
    }
}
