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
    @State private var refreshID = UUID().uuidString

    @Binding private var showsPanel: Bool
    @Binding private var sliderValue: Float
    @Binding private var setting: Setting
    @Binding private var autoPlayPolicy: AutoPlayPolicy
    private let currentIndex: Int
    private let range: ClosedRange<Float>
    private let previews: [Int: String]
    private let settingAction: () -> Void
    private let fetchAction: (Int) -> Void
    private let sliderChangedAction: (Int) -> Void
    private let updateSettingAction: (Setting) -> Void

    init(
        showsPanel: Binding<Bool>, sliderValue: Binding<Float>,
        setting: Binding<Setting>, autoPlayPolicy: Binding<AutoPlayPolicy>,
        currentIndex: Int, range: ClosedRange<Float>, previews: [Int: String],
        settingAction: @escaping () -> Void, fetchAction: @escaping (Int) -> Void,
        sliderChangedAction: @escaping (Int) -> Void,
        updateSettingAction: @escaping (Setting) -> Void
    ) {
        _showsPanel = showsPanel
        _sliderValue = sliderValue
        _setting = setting
        _autoPlayPolicy = autoPlayPolicy
        self.currentIndex = currentIndex
        self.range = range
        self.previews = previews
        self.settingAction = settingAction
        self.fetchAction = fetchAction
        self.sliderChangedAction = sliderChangedAction
        self.updateSettingAction = updateSettingAction
    }

    var body: some View {
        VStack {
            UpperPanel(
                title: "\(currentIndex) / " + "\(Int(range.upperBound))",
                setting: $setting, refreshID: $refreshID,
                autoPlayPolicy: $autoPlayPolicy,
                settingAction: settingAction,
                updateSettingAction: updateSettingAction
            )
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            if range.upperBound > range.lowerBound {
                LowerPanel(
                    sliderValue: $sliderValue, previews: previews, range: range,
                    isReversed: setting.readingDirection == .rightToLeft,
                    fetchAction: fetchAction, sliderChangedAction: sliderChangedAction
                )
                .offset(y: showsPanel ? 0 : 50)
            }
        }
        .opacity(showsPanel ? 1 : 0).disabled(!showsPanel)
        .onChange(of: showsPanel) { newValue in
            guard newValue else { return } // workaround
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshID = UUID().uuidString
            }
        }
    }
}

// MARK: UpperPanel
private struct UpperPanel: View {
    @Environment(\.dismiss) var dismissAction
    @Binding private var setting: Setting
    @Binding private var refreshID: String
    @Binding private var autoPlayPolicy: AutoPlayPolicy

    private let title: String
    private let settingAction: () -> Void
    private let updateSettingAction: (Setting) -> Void

    init(
        title: String, setting: Binding<Setting>,
        refreshID: Binding<String>, autoPlayPolicy: Binding<AutoPlayPolicy>,
        settingAction: @escaping () -> Void, updateSettingAction: @escaping (Setting) -> Void
    ) {
        self.title = title
        _setting = setting
        _refreshID = refreshID
        _autoPlayPolicy = autoPlayPolicy
        self.settingAction = settingAction
        self.updateSettingAction = updateSettingAction
    }

    var body: some View {
        ZStack {
            HStack {
                Button(action: dismissAction.callAsFunction) {
                    Image(systemName: "chevron.backward")
                }
                .font(.title2).padding(.leading, 20)
                Spacer()
                Slider(value: .constant(0)).opacity(0)
                Spacer()
                HStack(spacing: 20) {
                    if DeviceUtil.isLandscape && setting.readingDirection != .vertical {
                        Menu {
                            Button {
                                var setting = setting
                                setting.enablesDualPageMode.toggle()
                                updateSettingAction(setting)
                            } label: {
                                Text("Dual-page mode")
                                if setting.enablesDualPageMode {
                                    Image(systemName: "checkmark")
                                }
                            }
                            Button {
                                var setting = setting
                                setting.exceptCover.toggle()
                                updateSettingAction(setting)
                            } label: {
                                Text("Except the cover")
                                if setting.exceptCover {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .disabled(!setting.enablesDualPageMode)
                        } label: {
                            Image(systemName: "rectangle.split.2x1")
                                .symbolVariant(setting.enablesDualPageMode ? .fill : .none)
                        }
                    }
                    Image(systemName: "timer").opacity(0.01)
                        .overlay {
                            Menu {
                                Text("AutoPlay").foregroundColor(.secondary)
                                ForEach(AutoPlayPolicy.allCases) { policy in
                                    Button {
                                        autoPlayPolicy = policy
                                    } label: {
                                        Text(policy.descriptionKey)
                                        if autoPlayPolicy == policy {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "timer")
                            }
                        }
                        .id(refreshID)
                    Button(action: settingAction) {
                        Image(systemName: "gear")
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
    @State private var isSliderDragging = false
    @Binding var sliderValue: Float
    private let previews: [Int: String]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let fetchAction: (Int) -> Void
    private let sliderChangedAction: (Int) -> Void

    init(
        sliderValue: Binding<Float>, previews: [Int: String],
        range: ClosedRange<Float>, isReversed: Bool,
        fetchAction: @escaping (Int) -> Void,
        sliderChangedAction: @escaping (Int) -> Void
    ) {
        _sliderValue = sliderValue
        self.previews = previews
        self.range = range
        self.isReversed = isReversed
        self.fetchAction = fetchAction
        self.sliderChangedAction = sliderChangedAction
    }

    var body: some View {
        VStack(spacing: 0) {
            SliderPreivew(
                isSliderDragging: $isSliderDragging,
                sliderValue: $sliderValue, previews: previews, range: range,
                isReversed: isReversed, fetchAction: fetchAction
            )
            VStack {
                HStack {
                    Text(lowerBoundText).boundTextModifier()
                    Slider(
                        value: $sliderValue, in: range, step: 1,
                        onEditingChanged: { isDragging in
                            sliderChangedAction(Int(sliderValue))
                            HapticUtil.generateFeedback(style: .soft)
                            withAnimation {
                                isSliderDragging = isDragging
                            }
                        }
                    )
                    .rotationEffect(sliderAngle)
                    Text(upperBoundText).boundTextModifier()
                }
                .padding(.horizontal).padding(.bottom)
            }
        }
        .background(.thinMaterial)
    }
}

private extension LowerPanel {
    var lowerBoundText: String {
        isReversed ? "\(Int(range.upperBound))" : "\(Int(range.lowerBound))"
    }
    var upperBoundText: String {
        isReversed ? "\(Int(range.lowerBound))" : "\(Int(range.upperBound))"
    }
    var sliderAngle: Angle {
        Angle(degrees: isReversed ? 180 : 0)
    }
}

// MARK: SliderPreview
private struct SliderPreivew: View {
    @Binding private var isSliderDragging: Bool
    @Binding var sliderValue: Float
    private let previews: [Int: String]
    private let range: ClosedRange<Float>
    private let isReversed: Bool
    private let fetchAction: (Int) -> Void

    init(
        isSliderDragging: Binding<Bool>, sliderValue: Binding<Float>,
        previews: [Int: String], range: ClosedRange<Float>,
        isReversed: Bool, fetchAction: @escaping (Int) -> Void
    ) {
        _isSliderDragging = isSliderDragging
        _sliderValue = sliderValue
        self.previews = previews
        self.range = range
        self.isReversed = isReversed
        self.fetchAction = fetchAction
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
                        .frame(width: previewWidth, height: isSliderDragging ? previewHeight : 0)
                    Text("\(index)").font(DeviceUtil.isPadWidth ? .callout : .caption)
                        .foregroundColor(index == Int(sliderValue) ? .accentColor : .secondary)
                }
                .onAppear {
                    guard previews[index] == nil && checkIndex(index) else { return }
                    fetchAction(index)
                }
                .opacity(checkIndex(index) ? 1 : 0)
            }
        }
        .opacity(isSliderDragging ? 1 : 0).padding(.vertical, verticalPadding)
        .frame(height: isSliderDragging ? previewHeight + verticalPadding * 2 : 0)
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

private extension Text {
    func boundTextModifier() -> some View {
        self.fontWeight(.medium).font(.caption).padding()
    }
}
