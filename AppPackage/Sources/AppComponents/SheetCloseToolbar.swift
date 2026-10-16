public import SwiftUI

/// Keeps dismissal beside the sheet's title, including when other tools use a vertical bar.
public struct SheetCloseToolbar: ToolbarContent {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some ToolbarContent {
        if #available(iOS 27.1, *) {
            closeItem.axisBehavior(.horizontalOnly)
        } else {
            closeItem
        }
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close, action: dismiss.callAsFunction)
        }
    }
}
