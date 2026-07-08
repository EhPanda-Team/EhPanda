import SwiftUI
import SFSafeSymbols

/// A leading, non-interactive footnote notice (e.g. a size-cap explanation) meant to sit as a row
/// inside a `List`. Rendering it in the list, rather than pinning it above the list via
/// `.safeAreaInset`, keeps it scrolling with the content and leaves the navigation title intact.
public struct ListNoticeView: View {
    private let notice: LocalizedStringResource

    public init(notice: LocalizedStringResource) {
        self.notice = notice
    }

    public var body: some View {
        Label(
            title: {
                Text(notice)
                    .font(.footnote)
            },
            icon: {
                Image(systemSymbol: .infoCircle)
                    .imageScale(.small)
            }
        )
        .foregroundStyle(.secondary)
    }
}
