//
//  ControlPanel.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/07/30.
//

import SwiftUI
import Kingfisher

// MARK: ControlPanel
struct ControlPanel: View {
    @Binding private var showsPanel: Bool
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    @Binding private var setting: Setting
    @Binding private var autoPlayPolicy: AutoPlayPolicy
    private let range: ClosedRange<Float>
    private let previews: [Int: String]
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void
    private let fetchPreviewsAction: (Int) -> Void

    init(
        showsPanel: Binding<Bool>, showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        setting: Binding<Setting>, autoPlayPolicy: Binding<AutoPlayPolicy>, range: ClosedRange<Float>,
        previews: [Int: String], dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void,
        fetchPreviewsAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        _setting = setting
        _autoPlayPolicy = autoPlayPolicy
        self.range = range
        self.previews = previews
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
        self.fetchPreviewsAction = fetchPreviewsAction
    }

    private var title: String {
        ["\(max(Int(sliderValue), 1))", "\(Int(range.upperBound))"].joined(separator: " / ")
    }

    var body: some View {
        VStack {
            UpperPanel(
                title: title,
                setting: $setting,
                autoPlayPolicy: $autoPlayPolicy,
                dismissAction: dismissAction,
                navigateSettingAction: navigateSettingAction
            )
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            if range.upperBound > range.lowerBound {
                LowerPanel(
                    showsSliderPreview: $showsSliderPreview,
                    sliderValue: $sliderValue, previews: previews, range: range,
                    isReversed: setting.readingDirection == .rightToLeft,
                    fetchPreviewsAction: fetchPreviewsAction
                )
                .offset(y: showsPanel ? 0 : 50)
            }
        }
        .opacity(showsPanel ? 1 : 0).disabled(!showsPanel)
    }
}

// MARK: UpperPanel
private struct UpperPanel: View {
    @Binding private var setting: Setting
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let title: String
    private let dismissAction: () -> Void
    private let navigateSettingAction: () -> Void

    init(
        title: String, setting: Binding<Setting>,
        autoPlayPolicy: Binding<AutoPlayPolicy>,
        dismissAction: @escaping () -> Void,
        navigateSettingAction: @escaping () -> Void
    ) {
        self.title = title
        _setting = setting
        _autoPlayPolicy = autoPlayPolicy
        self.dismissAction = dismissAction
        self.navigateSettingAction = navigateSettingAction
    }

    var body: some View {
        ZStack {
            HStack {
                Button(action: dismissAction) {
                    Image(systemSymbol: .chevronDown)
                }
                .font(.title2).padding(.leading, 20)
                Spacer()
                Slider(value: .constant(0)).opacity(0)
                Spacer()
                HStack(spacing: 20) {
                    if DeviceUtil.isLandscape && setting.readingDirection != .vertical {
                        Menu {
                            Button {
                                setting.enablesDualPageMode.toggle()
                            } label: {
                                Text("Dual-page mode")
                                if setting.enablesDualPageMode {
                                    Image(systemSymbol: .checkmark)
                                }
                            }
                            Button {
                                setting.exceptCover.toggle()
                            } label: {
                                Text("Except the cover")
                                if setting.exceptCover {
                                    Image(systemSymbol: .checkmark)
                                }
                            }
                            .disabled(!setting.enablesDualPageMode)
                        } label: {
                            Image(systemSymbol: .rectangleSplit2x1)
                                .symbolVariant(setting.enablesDualPageMode ? .fill : .none)
                        }
                    }
                    Menu {
                        Text("AutoPlay").foregroundColor(.secondary)
                        ForEach(AutoPlayPolicy.allCases) { policy in
                            Button {
                                autoPlayPolicy = policy
                            } label: {
                                Text(policy.descriptionKey)
                                if autoPlayPolicy == policy {
                                    Image(systemSymbol: .checkmark)
                                }
                            }
                        }
                    } label: {
                        Image(systemSymbol: .timer)
                    }
                    Button(action: navigateSettingAction) {
                        Image(systemSymbol: .gear)
                    }
                    .padding(.trailing, 20)
                }
                .font(.title2)
            }
            Text(title).bold().lineLimit(1).padding()
        }
        .background(.thinMaterial)
    }
}

// MARK: LowerPanel
private struct LowerPanel: View {
    @Binding private var showsSliderPreview: Bool
    @Binding private var sliderValue: Float
    private let previews: [Int: String]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let fetchPreviewsAction: (Int) -> Void

    init(
        showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        previews: [Int: String], range: ClosedRange<Float>, isReversed: Bool,
        fetchPreviewsAction: @escaping (Int) -> Void
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previews = previews
        self.range = range
        self.isReversed = isReversed
        self.fetchPreviewsAction = fetchPreviewsAction
    }

    var body: some View {
        VStack(spacing: 0) {
            SliderPreivew(
                showsSliderPreview: $showsSliderPreview,
                sliderValue: $sliderValue, previews: previews, range: range,
                isReversed: isReversed, fetchPreviewsAction: fetchPreviewsAction
            )
            VStack {
                HStack {
                    Text(isReversed ? "\(Int(range.upperBound))" : "\(Int(range.lowerBound))")
                        .fontWeight(.medium).font(.caption).padding()
                    Slider(
                        value: $sliderValue, in: range, step: 1,
                        onEditingChanged: { showsSliderPreview = $0 }
                    )
                    .rotationEffect(.init(degrees: isReversed ? 180 : 0))
                    Text(isReversed ? "\(Int(range.lowerBound))" : "\(Int(range.upperBound))")
                        .fontWeight(.medium).font(.caption).padding()
                }
                .padding(.horizontal).padding(.bottom)
            }
        }
        .background(.thinMaterial)
    }
}

// MARK: SliderPreview
private struct SliderPreivew: View {
    @Binding private var showsSliderPreview: Bool
    @Binding var sliderValue: Float
    private let previews: [Int: String]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let fetchPreviewsAction: (Int) -> Void

    init(
        showsSliderPreview: Binding<Bool>, sliderValue: Binding<Float>,
        previews: [Int: String], range: ClosedRange<Float>,
        isReversed: Bool, fetchPreviewsAction: @escaping (Int) -> Void
    ) {
        _showsSliderPreview = showsSliderPreview
        _sliderValue = sliderValue
        self.previews = previews
        self.range = range
        self.isReversed = isReversed
        self.fetchPreviewsAction = fetchPreviewsAction
    }

    var body: some View {
        HStack(spacing: previewSpacing) {
            ForEach(previewsIndices, id: \.self) { index in
                let (url, modifier) =
                PreviewResolver.getPreviewConfigs(
                    originalURL: previews[index] ?? ""
                )
                VStack {
                    KFImage.url(URL(string: url), cacheKey: previews[index])
                        .placeholder {
                            Placeholder(style: .activity(
                                ratio: Defaults.ImageSize.previewAspect
                            ))
                        }
                        .fade(duration: 0.25)
                        .imageModifier(modifier).resizable().scaledToFit()
                        .frame(width: previewWidth, height: showsSliderPreview ? previewHeight : 0)
                    Text("\(index)").font(DeviceUtil.isPadWidth ? .callout : .caption)
                        .foregroundColor(index == Int(sliderValue) ? .accentColor : .secondary)
                }
                .onAppear {
                    if previews[index] == nil && checkIndex(index) {
                        fetchPreviewsAction(index)
                    }
                }
                .opacity(checkIndex(index) ? 1 : 0)
            }
        }
        .opacity(showsSliderPreview ? 1 : 0).padding(.vertical, verticalPadding)
        .frame(height: showsSliderPreview ? previewHeight + verticalPadding * 2 : 0)
    }
}

private extension SliderPreivew {
    var verticalPadding: CGFloat {
        DeviceUtil.isPadWidth ? 30 : 20
    }
    var previewsCount: Int {
        DeviceUtil.isPadWidth ? DeviceUtil.isLandscape ? 7 : 5 : 3
    }
    var previewsIndices: [Int] {
        guard !previews.isEmpty else { return [] }
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
        let spacing = (count + 1) * previewSpacing
        return (DeviceUtil.windowW - spacing) / count
    }
    func checkIndex(_ index: Int) -> Bool {
        index >= Int(range.lowerBound) && index <= Int(range.upperBound)
    }
}
