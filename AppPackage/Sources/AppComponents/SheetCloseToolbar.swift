public import SwiftUI

/// Keeps dismissal beside the sheet's title, including when other tools use a vertical bar.
public struct SheetCloseToolbar: ToolbarContent {
    @Environment(\.dismiss) private var dismiss

    private let action: (() -> Void)?

    public init(action: (() -> Void)? = nil) {
        self.action = action
    }

    public var body: some ToolbarContent {
        if #available(iOS 27.1, *) {
            closeItem.axisBehavior(.horizontalOnly)
        } else {
            closeItem
        }
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close, action: action ?? dismiss.callAsFunction)
        }
    }
}
