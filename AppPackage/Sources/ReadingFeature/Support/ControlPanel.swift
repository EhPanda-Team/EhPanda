import AppComponents
import AppModels
import AppTools
import Resources
import SFSafeSymbols
import SwiftUI

struct ControlPanel<G: Gesture>: View {
    // The panel is a custom overlay, not a sheet, so nothing moves VoiceOver into it by itself:
    // showing it lands focus on the lower Close button (the panel's first control), the way a
    // modal surface would. Hiding needs no counterpart — `.visible(false)` takes the panel out of
    // the accessibility tree and VoiceOver falls back to the page on its own.
    @AccessibilityFocusState private var isCloseButtonFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var showsPanel: Bool
    @Binding var showsSliderPreview: Bool
    @Binding var sliderValue: Float
    let isReversed: Bool
    let containerSize: CGSize
    let range: ClosedRange<Float>
    let previewURLs: [Int: URL]
    let dismissGesture: G
    let dismissAction: () -> Void
    let fetchPreviewURLsAction: (Int) -> Void

    /// Where the hidden panel rests: 50 pt below its shown position, so showing it is a rise
    /// paired with the fade `.visible(showsPanel)` provides. The rise is position motion, so under
    /// Reduce Motion the hidden panel sits in place and only the fade remains — the reader's
    /// `.animation(.default, value: store.showsPanel)` drives that half unchanged (D-29).
    private var hiddenPanelOffset: CGFloat { reduceMotion ? 0 : 50 }

    var body: some View {
        VStack {
            Spacer()
            if range.upperBound > range.lowerBound {
                LowerPanel(
                    closeButtonFocus: $isCloseButtonFocused,
                    showsSliderPreview: $showsSliderPreview,
                    sliderValue: $sliderValue, previewURLs: previewURLs, range: range,
                    isReversed: isReversed,
                    containerSize: containerSize,
                    dismissGesture: dismissGesture, dismissAction: dismissAction,
                    fetchPreviewURLsAction: fetchPreviewURLsAction
                )
                // The preview tray grows from zero height while the Close button fades out — size
                // motion, so under Reduce Motion the tray appears in place (D-29).
                .animation(reduceMotion ? nil : .default, value: showsSliderPreview)
                .offset(y: showsPanel ? 0 : hiddenPanelOffset)
            }
        }
        // Match the native reading toolbar: measured on iOS 26.5 from XS through AX5.
        // This owner-approved range also covers the preview and the lower Close button.
        .dynamicTypeSize(DynamicTypeSize.large...DynamicTypeSize.xxLarge)
        .visible(showsPanel)
        .disabled(!showsPanel)
        .onChange(of: showsPanel) { _, isShown in
            if isShown {
                isCloseButtonFocused = true
            }
        }
    }
}

// MARK: LowerPanel
private struct LowerPanel<G: Gesture>: View {
    @ScaledMetric(relativeTo: .title2) private var closeButtonSize: CGFloat = 44
    private let closeButtonFocus: AccessibilityFocusState<Bool>.Binding
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    private let previewURLs: [Int: URL]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let containerSize: CGSize
    private let dismissGesture: G
    private let dismissAction: () -> Void
    private let fetchPreviewURLsAction: (Int) -> Void

    init(
        closeButtonFocus: AccessibilityFocusState<Bool>.Binding,
        showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        previewURLs: [Int: URL], range: ClosedRange<Float>, isReversed: Bool,
        containerSize: CGSize, dismissGesture: G, dismissAction: @escaping () -> Void,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        self.closeButtonFocus = closeButtonFocus
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previewURLs = previewURLs
        self.range = range
        self.isReversed = isReversed
        self.containerSize = containerSize
        self.dismissGesture = dismissGesture
        self.dismissAction = dismissAction
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    var body: some View {
        VStack(spacing: 30) {
            Button(action: dismissAction) {
                Label(.close, systemSymbol: .xmark)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(width: closeButtonSize, height: closeButtonSize)
            }
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive())
            .gesture(dismissGesture)
            .accessibilityFocused(closeButtonFocus)
            .visible(!showsSliderPreview)

            VStack(spacing: 0) {
                SliderPreivew(
                    showsSliderPreview: $showsSliderPreview,
                    sliderValue: $sliderValue,
                    previewURLs: previewURLs,
                    range: range,
                    isReversed: isReversed,
                    containerSize: containerSize,
                    fetchPreviewURLsAction: fetchPreviewURLsAction
                )

                // A page number is a value, not a label: its digits carry no break opportunity, so
                // it either reads in full or not at all, and the single line says so explicitly.
                // The slider is the flexible member of the row — it takes whatever the two numbers
                // leave, up to its designed 60 % of the container, so a number that grew with the
                // reader's type size widens its end of the bar instead of losing digits to it. At
                // and below the default size the row has slack to spare, the slider still takes
                // the full 60 %, and the bar renders exactly as designed.
                HStack {
                    Text(isReversed ? Int(range.upperBound) : Int(range.lowerBound), format: .number)
                        .fontWeight(.medium)
                        .font(.caption)
                        .lineLimit(1)
                        .padding()

                    Slider(
                        value: $sliderValue,
                        in: range,
                        onEditingChanged: { if !$0 { showsSliderPreview = false } }
                    )
                    .frame(maxWidth: containerSize.width * 0.6)
                    .rotationEffect(.init(degrees: isReversed ? 180 : 0))
                    // The slider's own value would be a percentage; the page it stands for is the
                    // value that means something ("Page, 12 of 112"). `range.upperBound` is the
                    // gallery's page count — the reader passes `1...pageCount`.
                    .accessibilityLabel(.accessibilityPageSlider)
                    .accessibilityValue(
                        .accessibilityPageOf(current: Int(sliderValue), total: Int(range.upperBound))
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity)
                            .onChanged({ if $0 { showsSliderPreview = true } })
                    )

                    Text(isReversed ? Int(range.lowerBound) : Int(range.upperBound), format: .number)
                        .fontWeight(.medium)
                        .font(.caption)
                        .lineLimit(1)
                        .padding()
                }
            }
            .glassEffect(in: .rect(cornerRadius: 16))
            .padding(.horizontal, SliderPreivew.outerPadding)
        }
    }
}

// MARK: SliderPreview
private struct SliderPreivew: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .callout) private var scaledPreviewLabelClearance: CGFloat = 28
    @Binding private var showsSliderPreview: Bool
    @Binding var sliderValue: Float
    private let previewURLs: [Int: URL]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let containerSize: CGSize
    private let fetchPreviewURLsAction: (Int) -> Void
    // The designed 28pt clearance covers one regular-width `.large` callout line plus the
    // existing 8pt VStack spacing. Subtracting it preserves the exact `.large` tray height.
    private let designedPreviewLabelClearance: CGFloat = 28

    static let outerPadding: CGFloat = 8

    init(
        showsSliderPreview: Binding<Bool>,
        sliderValue: Binding<Float>,
        previewURLs: [Int: URL],
        range: ClosedRange<Float>,
        isReversed: Bool,
        containerSize: CGSize,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previewURLs = previewURLs
        self.range = range
        self.isReversed = isReversed
        self.containerSize = containerSize
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    var body: some View {
        HStack(spacing: previewSpacing) {
            ForEach(previewsIndices, id: \.self) { page in
                VStack {
                    PreviewImageView(originalURL: previewURLs[page])
                        .frame(width: previewWidth, height: showsSliderPreview ? previewHeight : 0)

                    Text(page, format: .number)
                        .font(horizontalSizeClass == .regular ? .callout : .caption)
                        .foregroundStyle(page == Int(sliderValue) ? Color.accentColor : Color.secondary)
                }
                .visible(checkIndex(page))
            }
        }
        // The window of slots is a pure function of `sliderValue` (and the size class / container
        // size), so the set of indices needing a URL is a *value*, not an appearance event: this
        // fires for the opening window via `initial: true` and again for every window the slider
        // drags into. That is the same set the per-slot `.onAppear` used to cover, minus the
        // dependency on when SwiftUI happens to build a slot.
        .onChange(of: previewsIndices, initial: true) { _, pages in
            for page in pages where previewURLs[page] == nil && checkIndex(page) {
                fetchPreviewURLsAction(page)
            }
        }
        .visible(showsSliderPreview)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(
            height: showsSliderPreview
                ? previewHeight + verticalPadding * 2 + previewLabelClearanceGrowth
                : 0
        )
    }
}

private extension SliderPreivew {
    var verticalPadding: CGFloat {
        horizontalSizeClass == .regular ? 30 : 20
    }
    var horizontalPadding: CGFloat { verticalPadding * 0.5 }
    var previewsCount: Int {
        horizontalSizeClass == .regular ? isLandscape ? 7 : 5 : 3
    }
    var previewsIndices: [Int] {
        // Do NOT gate this on `previewURLs` being non-empty: this window drives
        // `fetchPreviewURLsAction`, so returning [] while empty deadlocks the tray (no indices →
        // no fetch → stays blank forever). `checkIndex` handles the bounds.
        let currentIndex = Int(sliderValue)
        let distance = (previewsCount - 1) / 2
        let lowerBound = currentIndex - distance
        let upperBound = currentIndex + distance

        let indices = Array(lowerBound...upperBound)
        return isReversed ? indices.reversed() : indices
    }
    var previewSpacing: CGFloat { 10 }
    var previewHeight: CGFloat {
        previewWidth / Defaults.ImageSize.previewAspect
    }
    var previewLabelClearanceGrowth: CGFloat {
        max(scaledPreviewLabelClearance - designedPreviewLabelClearance, 0)
    }
    var previewWidth: CGFloat {
        guard previewsCount > 0 else { return 0 }
        let count = CGFloat(previewsCount)
        let spacing = (count + 1) * previewSpacing + horizontalPadding * 2 + Self.outerPadding * 2
        return max((containerSize.width - spacing) / count, 0)
    }
    var isLandscape: Bool { containerSize.width > containerSize.height }
    func checkIndex(_ index: Int) -> Bool {
        index >= Int(range.lowerBound) && index <= Int(range.upperBound)
    }
}

private let previewContainerSize = CGSize(width: 375, height: 667)

@MainActor private func previewControlPanel() -> some View {
    ControlPanel(
        showsPanel: .constant(true),
        showsSliderPreview: .constant(false),
        sliderValue: .constant(1),
        isReversed: false,
        containerSize: previewContainerSize,
        range: 1...14,
        previewURLs: [:],
        dismissGesture: TapGesture(),
        dismissAction: {},
        fetchPreviewURLsAction: { _ in }
    )
    .background(.black)
}

#Preview("Default size, portrait", traits: .fixedLayout(width: 375, height: 667)) {
    previewControlPanel()
}

#Preview("Accessibility 5, portrait", traits: .fixedLayout(width: 375, height: 667)) {
    previewControlPanel()
        .environment(\.dynamicTypeSize, .accessibility5)
}
