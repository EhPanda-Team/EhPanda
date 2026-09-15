import AppTools
import Dependencies
import HapticsClient
import Resources
import SwiftUI

public struct SubSection<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Dependency(\.hapticsClient) private var hapticsClient
    private let title: LocalizedStringResource
    private let showAll: Bool
    private let isLoading: Bool?
    private let reloadAction: (() -> Void)?
    private let showAllAction: () -> Void
    private let content: Content

    public init(
        title: LocalizedStringResource, showAll: Bool = true,
        isLoading: Bool? = nil,
        reloadAction: (() -> Void)? = nil,
        showAllAction: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showAll = showAll
        self.isLoading = isLoading
        self.reloadAction = reloadAction
        self.showAllAction = showAllAction
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading) {
            heading.padding(.horizontal)

            content
        }
    }

    /// **Show All** is intrinsically sized and refuses to compress, so on a row it takes its width
    /// first and leaves the heading whatever is left. At an accessibility size that remainder is
    /// narrower than a single word, and the title degenerates into one character per line beside
    /// it (Phase 16 findings #10 and #34). Giving the title a line of its own hands it the row's
    /// whole width, which is the only width there is to give, and puts **Show All** on the next
    /// line under it rather than off the leading edge of its own column.
    ///
    /// The arrangement is chosen by an explicit size read rather than by `ViewThatFits`, because
    /// the title wraps: its *ideal* width is its full single-line width, so every candidate holding
    /// it measures as not fitting and the stacked one would win at every size, the default
    /// included.
    ///
    /// The two controls are one heading block, so 8 points hold them closer together than the
    /// enclosing `VStack`'s default spacing holds the heading to the section's content: the gap
    /// has to read as "these belong together", while still being wide enough that two large
    /// tappable labels are not mistaken for one wrapped sentence. The `.padding(.horizontal)` sits
    /// outside the branch, so the stacked lines keep the same margins the row had and no text ends
    /// up against the screen edge.
    ///
    /// The two branches treat a hidden **Show All** differently, and deliberately so. On the row it
    /// keeps drawing the button at zero opacity: it reserves its width, so the heading beside it is
    /// laid out identically whether or not the section offers the action. Stacked, that same trick
    /// would reserve a whole *line* — a blank 50 to 65 points under the half of the call sites that
    /// pass `showAll: false` — so the accessibility branch does not build the button at all. The
    /// difference is confined to layout: `visible(_:)` takes the invisible button out of the
    /// accessibility tree, so neither branch offers a control that cannot be seen.
    @ViewBuilder private var heading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                titleButton
                if showAll {
                    showAllButton
                }
            }
        } else {
            HStack {
                titleButton
                showAllButton
            }
        }
    }

    /// A `Button` centres a multi-line label, which is what turned the wrapped heading into a
    /// column of centred fragments; the leading alignment is stated explicitly so it survives
    /// however the title breaks. A single-line title — every title at the default size — renders
    /// exactly as before.
    private var titleButton: some View {
        Button {
            reloadAction?()
            hapticsClient.generateFeedback(.soft)
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.leading)
                ProgressView()
                    .animation(.default) {
                        $0.visible(isLoading == true)
                    }
            }
        }
        .allowsHitTesting(reloadAction != nil)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Leading-aligned for the same reason as the title: a locale whose "Show All" is long enough
    /// to wrap would otherwise centre its lines under a leading-aligned heading.
    private var showAllButton: some View {
        Button(action: showAllAction) {
            Text(.showAll)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .visible(showAll)
    }
}

#Preview("Default") {
    SubSection(title: "Popular") {
        Text(verbatim: "Content")
    }
}

#Preview("Loading, no show-all") {
    SubSection(title: "Popular", showAll: false, isLoading: true, reloadAction: {}) {
        Text(verbatim: "Content")
    }
}

#Preview("Accessibility size") {
    SubSection(title: "Quick Search", reloadAction: {}) {
        Text(verbatim: "Content")
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
