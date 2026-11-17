import Foundation
import SwiftUI
import UIKit

/// The accessibility elements of a hosted SwiftUI view, as UIKit exposes them to assistive technologies.
@MainActor
enum AccessibilityElements {
    /// SwiftUI builds its accessibility elements only while accessibility is on in the process, which a test process
    /// does not have unless it asks, as an assistive technology would.
    private static let enableAccessibility: Void = {
        guard let library = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let symbol = dlsym(library, "_AXSApplicationAccessibilitySetEnabled")
        else { return }
        typealias SetEnabled = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(true)
    }()

    /// Hosts `view` in a window of `size` (``HostedView``) and hands every accessibility element under it to `body`,
    /// while the window is still up.
    static func read<Result>(
        of view: some View, size: CGSize, _ body: ([NSObject]) throws -> Result
    ) throws -> Result {
        _ = enableAccessibility
        return try HostedView.withRoot(of: view, size: size) { root in
            try body(elements(under: root, depth: 0))
        }
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
