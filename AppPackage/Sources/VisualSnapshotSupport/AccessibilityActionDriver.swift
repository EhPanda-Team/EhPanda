public import UIKit

/// Performs a named accessibility custom action of a hosted view, the way VoiceOver or Voice Control would.
///
/// A few scenario states are reached only through a row's own action, never through store state (a moderation alert
/// is presented by the row that asked for it). Scenarios reach them through the accessibility actions the row already
/// offers, so no capture-only code enters the app (19-CONTEXT D-08, D-27). The simulator must load the app's
/// accessibility runtime (`ApplicationAccessibilityEnabled`, set with Reduce Motion before a run); without it the
/// hosted views expose no elements and the action is `notFound`.
@MainActor
public enum AccessibilityActionDriver {
    public enum Failure: Error, Equatable {
        case notFound(String)
        case refused(String)
    }

    /// Finds the first element below `root` that offers an action named `name` and performs it.
    public static func perform(_ name: String, in root: UIView) throws {
        var found: UIAccessibilityCustomAction?
        visit(root, depth: 0) { element in
            found = element.accessibilityCustomActions?.first(where: { $0.name == name })
            return found != nil
        }
        guard let action = found else { throw Failure.notFound(name) }
        let handled: Bool
        if let handler = action.actionHandler {
            handled = handler(action)
        } else if let target = action.target as? NSObject {
            handled = target.perform(action.selector, with: action) != nil
        } else {
            handled = false
        }
        guard handled else { throw Failure.refused(name) }
    }

    /// Every action name offered below `root`, for diagnostics.
    public static func actionNames(in root: UIView) -> [String] {
        var names: [String] = []
        visit(root, depth: 0) { element in
            names += (element.accessibilityCustomActions ?? []).map(\.name)
            return false
        }
        return names
    }

    /// Walks views and their accessibility elements depth first until `body` returns `true`.
    @discardableResult
    private static func visit(_ element: NSObject, depth: Int, body: (NSObject) -> Bool) -> Bool {
        guard depth < 64 else { return false }
        if body(element) { return true }
        var children: [NSObject] = []
        if let elements = element.accessibilityElements as? [NSObject] {
            children += elements
        } else {
            let count = element.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                children += (0..<count).compactMap({ element.accessibilityElement(at: $0) as? NSObject })
            }
        }
        if let view = element as? UIView {
            children += view.subviews
        }
        for child in children where visit(child, depth: depth + 1, body: body) {
            return true
        }
        return false
    }
}
