import AppComponents
import ComposableArchitecture
import Foundation
import SwiftUI

/// The first launch (UI-SPEC C-1, DD-06): the age wall, then the analytics choice. `RootView` renders it instead of
/// the app until both are answered, so nothing of the app exists behind it. It has no navigation bar, back, close or
/// skip.
///
/// The step comes from the stored answers (`FirstLaunchReducer.State.step`), so an upgrader who answered the age
/// wall and quit before choosing opens on the analytics choice. The age wall slides out to the leading edge as the
/// choice slides in from the trailing one; under Reduce Motion the two crossfade. VoiceOver focus moves to each
/// screen's title as it appears.
struct FirstLaunchGateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedTitle: FirstLaunchReducer.Step?

    @Bindable private var store: StoreOf<FirstLaunchReducer>

    init(store: StoreOf<FirstLaunchReducer>) {
        self.store = store
    }

    var body: some View {
        ZStack {
            switch store.step {
            case .ageWall:
                AgeWallView(store: store, titleFocus: $focusedTitle)
                    .transition(stepTransition)
            case .analyticsChoice, .complete:
                AnalyticsChoiceView(store: store, titleFocus: $focusedTitle)
                    .transition(stepTransition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35), value: store.step)
        .background(Color(.systemGroupedBackground))
        .onChange(of: store.step, initial: true) { _, step in
            focusedTitle = step
        }
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

/// One first-launch screen's frame (UI-SPEC C-1): a scrolling column capped at 560pt with 24pt margins, and the
/// screen's Continue (with anything under it) in a bar pinned to the bottom at every text size (D-17b, owner msg
/// 1903), so Continue is one tap away without scrolling. The last scroll item ends 24pt above the bar.
///
/// The top padding reads only the horizontal size class, never the device. `identifier` names the scroll view, for
/// UI tests.
struct FirstLaunchPage<Content: View, Bottom: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let identifier: String
    private let compactTop: CGFloat
    private let regularTop: CGFloat
    private let content: Content
    private let bottom: Bottom

    init(
        identifier: String,
        compactTop: CGFloat,
        regularTop: CGFloat,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.identifier = identifier
        self.compactTop = compactTop
        self.regularTop = regularTop
        self.content = content()
        self.bottom = bottom()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content
            }
            .padding(.top, horizontalSizeClass == .regular ? regularTop : compactTop)
            .padding(.bottom, 24)
            .column()
        }
        .accessibilityIdentifier(identifier)
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .safeAreaBar(edge: .bottom) {
            bottom
                .padding(.top, 8)
                .padding(.bottom, 16)
                .column()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private extension View {
    /// The first-launch column: 24pt side margins inside a width capped at 560pt, centred.
    func column() -> some View {
        padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
    }
}

/// A first-launch screen's title (UI-SPEC C-2, C-3): bold `.title`, centred, wrapping freely, with no line break,
/// scaling, line limit or fixed width (owner msg 1822).
///
/// SwiftUI pulls a word down to keep a single word off the last line in English but not in German, so the title
/// carries `TitleWidowGuard` (lead msg 1900): it joins the last two words with a no-break space when they fit on one
/// line at the current width and text size. The catalog string and the visible words are unchanged, and VoiceOver
/// reads the string as written.
struct FirstLaunchTitle: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0

    private let title: String

    init(_ resource: LocalizedStringResource) {
        title = String(localized: resource)
    }

    var body: some View {
        Text(verbatim: guardedTitle)
            .font(.title.bold())
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                availableWidth = width
            }
            .accessibilityLabel(title)
    }

    private var guardedTitle: String {
        TitleWidowGuard.guarded(
            title, width: availableWidth, font: TitleWidowGuard.boldFont(.title1, at: dynamicTypeSize)
        )
    }
}
