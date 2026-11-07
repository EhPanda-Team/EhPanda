@testable import DetailFeature
import Foundation
import SwiftUI
import Testing
import UIKit

/// The line above a revealed comment (UI-SPEC C-7) at the largest text size on a narrow phone: the label and the Hide
/// pill both keep whole words. Shared with the label and the pill of the collapsed row (C-6), so the row's one-word
/// Show pill gives the height a pill has on one line.
@MainActor
struct RevealedCommentLineLayoutTests {
    /// The comments list's row width on the narrowest supported phone, inside the row's padding.
    private static let width: CGFloat = 343
    private static let label = "Comment from a user you've blocked"

    @Test
    func atAX5TheHidePillStaysOnOneLineAndTheLabelKeepsTheWidth() throws {
        let line = LaidOutElements(
            of: RevealedCommentLine(hideAction: {}), width: Self.width, size: .accessibility5
        )
        let row = LaidOutElements(
            of: BlockedCommentRow(commentID: "6894060", showAction: {}, unblockAction: {}),
            width: Self.width, size: .accessibility5
        )

        let hide = try #require(line.frame(labelled: "Hide"))
        let label = try #require(line.frame(labelled: Self.label))
        let show = try #require(row.frame(labelled: "Show"))

        #expect(hide.height <= show.height + 0.5, "Hide wraps: \(hide.height)pt against Show's \(show.height)pt.")
        #expect(label.width >= Self.width * 0.6, "The label is squeezed to \(label.width)pt.")
    }

    @Test
    func atTheDefaultSizeHideSitsBesideTheLabel() throws {
        let line = LaidOutElements(of: RevealedCommentLine(hideAction: {}), width: Self.width, size: .large)

        let hide = try #require(line.frame(labelled: "Hide"))
        let label = try #require(line.frame(labelled: Self.label))

        #expect(hide.minX > label.maxX, "Hide is not beside the label.")
        #expect(abs(hide.midY - label.midY) < 1, "Hide is not on the label's line.")
    }
}

/// The accessibility elements of a SwiftUI view laid out at `width` and a Dynamic Type size, with their frames.
@MainActor
private struct LaidOutElements {
    /// SwiftUI builds its accessibility elements only while accessibility is on in the process, which a test process
    /// does not have unless it asks, as an assistive technology would.
    private static let enableAccessibility: Void = {
        guard let library = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let symbol = dlsym(library, "_AXSApplicationAccessibilitySetEnabled")
        else { return }
        typealias SetEnabled = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(true)
    }()

    private let frames: [(label: String, frame: CGRect)]

    init(of view: some View, width: CGFloat, size: DynamicTypeSize) {
        _ = Self.enableAccessibility
        let controller = UIHostingController(rootView: view
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.dynamicTypeSize, size)
            .environment(\.locale, Locale(identifier: "en_US"))
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width + 40, height: 2000))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: .now.addingTimeInterval(0.2))
        frames = Self.elements(under: controller.view, depth: 0).compactMap { element in
            guard let label = element.accessibilityLabel, !label.isEmpty else { return nil }
            return (label, element.accessibilityFrame)
        }
    }

    func frame(labelled label: String) -> CGRect? {
        frames.first(where: { $0.label == label })?.frame
    }

    private static func elements(under object: NSObject, depth: Int) -> [NSObject] {
        guard depth < 40 else { return [object] }
        var children = (object.accessibilityElements ?? []).compactMap({ $0 as? NSObject })
        if children.isEmpty {
            let count = object.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                children = (0..<count).compactMap({ object.accessibilityElement(at: $0) as? NSObject })
            }
        }
        if children.isEmpty, let view = object as? UIView {
            children = view.subviews
        }
        return [object] + children.flatMap({ elements(under: $0, depth: depth + 1) })
    }
}
