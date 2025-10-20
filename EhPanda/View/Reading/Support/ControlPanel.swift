//
//  ControlPanel.swift
//  EhPanda
//

import SwiftUI
import Kingfisher

// MARK: ControlPanel
struct ControlPanel<G: Gesture>: View {
    @Binding private var showsPanel: Bool
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    @Binding private var setting: Setting
    @Binding private var enablesLiveText: Bool
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let range: ClosedRange<Float>
    private let previewURLs: [Int: URL]
    private let dismissGesture: G
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let reloadAllImagesAction: () -> Void
    private let retryAllFailedImagesAction: () -> Void
    private let fetchPreviewURLsAction: (Int) -> Void

    init(
        showsPanel: Binding<Bool>,
        showsSliderPreview: Binding<Bool>,
        sliderValue: Binding<Float>,
        setting: Binding<Setting>,
        enablesLiveText: Binding<Bool>,
        autoPlayPolicy: Binding<AutoPlayPolicy>,
        range: ClosedRange<Float>,
        previewURLs: [Int: URL],
        dismissGesture: G,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        reloadAllImagesAction: @escaping () -> Void,
        retryAllFailedImagesAction: @escaping () -> Void,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        _setting = setting
        _enablesLiveText = enablesLiveText
        _autoPlayPolicy = autoPlayPolicy
        self.range = range
        self.previewURLs = previewURLs
        self.dismissGesture = dismissGesture
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.reloadAllImagesAction = reloadAllImagesAction
        self.retryAllFailedImagesAction = retryAllFailedImagesAction
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    private var title: String {
        ["\(max(Int(sliderValue), 1))", "\(Int(range.upperBound))"].joined(separator: " / ")
    }

    var body: some View {
        VStack {
            UpperPanel(
                title: title,
                setting: $setting,
                enablesLiveText: $enablesLiveText,
                autoPlayPolicy: $autoPlayPolicy,
                dismissAction: dismissAction,
                navigateSettingAction: navigateSettingAction,
                reloadAllImagesAction: reloadAllImagesAction,
                retryAllFailedImagesAction: retryAllFailedImagesAction
            )
            .offset(y: showsPanel ? 0 : -50)

            Spacer()

            if range.upperBound > range.lowerBound {
                LowerPanel(
                    showsSliderPreview: $showsSliderPreview,
                    sliderValue: $sliderValue,
                    previewURLs: previewURLs,
                    range: range,
                    isReversed: setting.readingDirection == .rightToLeft,
                    dismissGesture: dismissGesture,
                    dismissAction: dismissAction,
                    fetchPreviewURLsAction: fetchPreviewURLsAction
                )
                .animation(.default, value: showsSliderPreview)
                .offset(y: showsPanel ? 0 : 50)
            }
        }
        .opacity(showsPanel ? 1 : 0).disabled(!showsPanel)
    }
}

// MARK: UpperPanel
private struct UpperPanel: View {
    @Binding private var setting: Setting
    @Binding private var enablesLiveText: Bool
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let title: String
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let reloadAllImagesAction: () -> Void
    private let retryAllFailedImagesAction: () -> Void

    init(
        title: String,
        setting: Binding<Setting>,
        enablesLiveText: Binding<Bool>,
        autoPlayPolicy: Binding<AutoPlayPolicy>,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        reloadAllImagesAction: @escaping () -> Void,
        retryAllFailedImagesAction: @escaping () -> Void
    ) {
        self.title = title
        _setting = setting
        _enablesLiveText = enablesLiveText
        _autoPlayPolicy = autoPlayPolicy
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.reloadAllImagesAction = reloadAllImagesAction
        self.retryAllFailedImagesAction = retryAllFailedImagesAction
    }

    var body: some View {
        HStack {
            // Liquid Glass Dismiss Button
            Button(action: dismissAction) {
                Image(systemSymbol: .xmark)
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive())

            Spacer()

            // Page Number Display in Liquid Glass Bubble
            Text(title)
                .bold()
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect()

            Spacer()

            // Toolbar Grouped in Liquid Glass Container
            HStack(spacing: 16) {
                Button {
                    enablesLiveText.toggle()
                } label: {
                    Image(systemSymbol: .viewfinderCircle)
                        .symbolVariant(enablesLiveText ? .fill : .none)
                        .font(.title2)
                }

                if DeviceUtil.isLandscape && setting.readingDirection != .vertical {
                    Menu {
                        Button {
                            setting.enablesDualPageMode.toggle()
                        } label: {
                            Text(L10n.Localizable.ReadingView.ToolbarItem.Title.dualPageMode)
                            if setting.enablesDualPageMode {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                        Button {
                            setting.exceptCover.toggle()
                        } label: {
                            Text(L10n.Localizable.ReadingView.ToolbarItem.Title.exceptTheCover)
                            if setting.exceptCover {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                        .disabled(!setting.enablesDualPageMode)
                    } label: {
                        Image(systemSymbol: .rectangleSplit2x1)
                            .symbolVariant(setting.enablesDualPageMode ? .fill : .none)
                            .font(.title2)
                    }
                }

                Menu {
                    Text(L10n.Localizable.ReadingView.ToolbarItem.Title.autoPlay).foregroundColor(.secondary)
                    ForEach(AutoPlayPolicy.allCases) { policy in
                        Button {
                            autoPlayPolicy = policy
                        } label: {
                            Text(policy.value)
                            if autoPlayPolicy == policy {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                    }
                } label: {
                    Image(systemSymbol: .timer)
                        .font(.title2)
                }
                .buttonStyle(.borderless)

                ToolbarFeaturesMenu {
                    Button(action: retryAllFailedImagesAction) {
                        Image(systemSymbol: .exclamationmarkArrowTriangle2Circlepath)
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Button.retryAllFailedImages)
                    }
                    Button(action: reloadAllImagesAction) {
                        Image(systemSymbol: .arrowCounterclockwise)
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Button.reloadAllImages)
                    }
                    Button(action: navigateSettingAction) {
                        Image(systemSymbol: .gear)
                        Text(L10n.Localizable.ReadingView.ToolbarItem.Button.readingSetting)
                    }
                }
                .buttonStyle(.borderless)
                .font(.title2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .glassEffect(.regular.interactive())
        }
        .padding(.horizontal, 20)
    }
}

// MARK: LowerPanel
private struct LowerPanel<G: Gesture>: View {
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    private let previewURLs: [Int: URL]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let dismissGesture: G
    private let dismissAction: () -> Void
    private let fetchPreviewURLsAction: (Int) -> Void

    init(
        showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        previewURLs: [Int: URL], range: ClosedRange<Float>, isReversed: Bool,
        dismissGesture: G, dismissAction: @escaping () -> Void,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previewURLs = previewURLs
        self.range = range
        self.isReversed = isReversed
        self.dismissGesture = dismissGesture
        self.dismissAction = dismissAction
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    var body: some View {
        VStack(spacing: 30) {
            // Dismiss Button
            Button(action: dismissAction) {
                Image(systemSymbol: .xmark)
                    .foregroundColor(.primary)
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive())
            .gesture(dismissGesture)
            .opacity(showsSliderPreview ? 0 : 1)

            // Slider in Liquid Glass Bubble
            VStack(spacing: 0) {
                SliderPreivew(
                    showsSliderPreview: $showsSliderPreview,
                    sliderValue: $sliderValue,
                    previewURLs: previewURLs,
                    range: range,
                    isReversed: isReversed,
                    fetchPreviewURLsAction: fetchPreviewURLsAction
                )

                HStack {
                    Text(isReversed ? "\(Int(range.upperBound))" : "\(Int(range.lowerBound))")
                        .fontWeight(.medium)
                        .font(.caption)
                        .padding()

                    Slider(
                        value: $sliderValue,
                        in: range,
                        onEditingChanged: { if !$0 { showsSliderPreview = false } }
                    )
                    // wtaf is happening here?
                    .frame(width: DeviceUtil.windowW * 0.6)
                    .rotationEffect(.init(degrees: isReversed ? 180 : 0))
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity)
                            .onChanged({ if $0 { showsSliderPreview = true } })
                    )

                    Text(isReversed ? "\(Int(range.lowerBound))" : "\(Int(range.upperBound))")
                        .fontWeight(.medium)
                        .font(.caption)
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
    @Binding private var showsSliderPreview: Bool
    @Binding var sliderValue: Float
    private let previewURLs: [Int: URL]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let fetchPreviewURLsAction: (Int) -> Void

    static let outerPadding: CGFloat = 8

    init(
        showsSliderPreview: Binding<Bool>,
        sliderValue: Binding<Float>,
        previewURLs: [Int: URL],
        range: ClosedRange<Float>,
        isReversed: Bool,
        fetchPreviewURLsAction: @escaping (Int) -> Void
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previewURLs = previewURLs
        self.range = range
        self.isReversed = isReversed
        self.fetchPreviewURLsAction = fetchPreviewURLsAction
    }

    var body: some View {
        HStack(spacing: previewSpacing) {
            ForEach(previewsIndices, id: \.self) { index in
                let (url, modifier) = PreviewResolver.getPreviewConfigs(originalURL: previewURLs[index])
                VStack {
                    KFImage.url(url, cacheKey: previewURLs[index]?.absoluteString)
                        .placeholder({ Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) })
                        .fade(duration: 0.25)
                        .imageModifier(modifier)
                        .resizable()
                        .scaledToFit()
                        .frame(width: previewWidth, height: showsSliderPreview ? previewHeight : 0)

                    Text("\(index)")
                        .font(DeviceUtil.isPadWidth ? .callout : .caption)
                        .foregroundColor(index == Int(sliderValue) ? .accentColor : .secondary)
                }
                .onAppear {
                    if previewURLs[index] == nil && checkIndex(index) {
                        fetchPreviewURLsAction(index)
                    }
                }
                .opacity(checkIndex(index) ? 1 : 0)
            }
        }
        .opacity(showsSliderPreview ? 1 : 0)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(height: showsSliderPreview ? previewHeight + verticalPadding * 2 : 0)
    }
}

private extension SliderPreivew {
    var verticalPadding: CGFloat {
        DeviceUtil.isPadWidth ? 30 : 20
    }
    var horizontalPadding: CGFloat { verticalPadding * 0.5 }
    var previewsCount: Int {
        DeviceUtil.isPadWidth ? DeviceUtil.isLandscape ? 7 : 5 : 3
    }
    var previewsIndices: [Int] {
        guard !previewURLs.isEmpty else { return [] }
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
    var previewWidth: CGFloat {
        guard previewsCount > 0 else { return 0 }
        let count = CGFloat(previewsCount)
        let spacing = (count + 1) * previewSpacing + horizontalPadding * 2 + Self.outerPadding * 2
        return (DeviceUtil.windowW - spacing) / count
    }
    func checkIndex(_ index: Int) -> Bool {
        index >= Int(range.lowerBound) && index <= Int(range.upperBound)
    }
}
