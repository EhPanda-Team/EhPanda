import SwiftUI

/// An always-visible footnote notice, meant to be pinned to the top of a list via `.safeAreaInset`,
/// explaining that the list has a size cap. The caller supplies the localized `Text` so each feature
/// keeps its own module-local string; only the identical presentation is shared here.
public struct LimitBanner: View {
    private let text: Text

    public init(_ text: Text) {
        self.text = text
    }

    public var body: some View {
        text
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
    }
}
