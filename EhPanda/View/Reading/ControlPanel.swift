//
//  ControlPanel.swift
//  ControlPanel
//
//  Created by 荒木辰造 on 2021/07/30.
//

import SwiftUI
import Kingfisher

// MARK: ControlPanel
struct ControlPanel: View {
    @Binding private var showsPanel: Bool
    @Binding private var sliderValue: Float
    @Binding private var setting: Setting
    private let currentIndex: Int
    private let range: ClosedRange<Float>
    private let previews: [Int: String]
    private let settingAction: () -> Void
    private let fetchAction: (Int) -> Void
    private let sliderChangedAction: (Int) -> Void
    private let updateSettingAction: (Setting) -> Void

    init(
        showsPanel: Binding<Bool>,
        sliderValue: Binding<Float>,
        setting: Binding<Setting>,
        currentIndex: Int,
        range: ClosedRange<Float>,
        previews: [Int: String],
        settingAction: @escaping () -> Void,
        fetchAction: @escaping (Int) -> Void,
        sliderChangedAction: @escaping (Int) -> Void,
        updateSettingAction: @escaping (Setting) -> Void
    ) {
        _showsPanel = showsPanel
        _sliderValue = sliderValue
        _setting = setting
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
                title: "\(currentIndex) / "
                + "\(Int(range.upperBound))",
                setting: $setting,
                settingAction: settingAction,
                updateSettingAction: updateSettingAction
            )
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            if range.upperBound > range.lowerBound {
                LowerPanel(
                    sliderValue: $sliderValue,
                    previews: previews, range: range,
                    isReversed: setting
                        .readingDirection == .rightToLeft,
                    fetchAction: fetchAction,
                    sliderChangedAction: sliderChangedAction
                )
                .offset(y: showsPanel ? 0 : 50)
            }
        }
        .opacity(showsPanel ? 1 : 0)
        .disabled(!showsPanel)
    }
}

// MARK: UpperPanel
private struct UpperPanel: View {
    @Environment(\.dismiss) var dismissAction
    @Binding var setting: Setting

    private let title: String
    private let settingAction: () -> Void
    private let updateSettingAction: (Setting) -> Void

    init(
        title: String, setting: Binding<Setting>,
        settingAction: @escaping () -> Void,
        updateSettingAction: @escaping (Setting) -> Void
    ) {
        self.title = title
        _setting = setting
        self.settingAction = settingAction
        self.updateSettingAction = updateSettingAction
    }

    var body: some View {
        ZStack {
            HStack {
                Button(action: dismissAction.callAsFunction) {
                    Image(systemName: "chevron.backward")
                }
                .font(.title2)
                .padding(.leading, 20)
                Spacer()
                Slider(value: .constant(0))
                    .opacity(0)
                Spacer()
                if isPad && isLandscape {
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
                    .font(.title2)
                    .padding()
                }
                Button(action: settingAction) {
                    Image(systemName: "gear")
                }
                .font(.title2)
                .padding(.trailing, 20)
            }
            Text(title).bold()
                .lineLimit(1)
                .padding()
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
        sliderValue: Binding<Float>,
        previews: [Int: String],
        range: ClosedRange<Float>,
        isReversed: Bool,
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
                sliderValue: $sliderValue,
                previews: previews,
                range: range,
                isReversed: isReversed,
                fetchAction: fetchAction
            )
            VStack {
                HStack {
                    Text(lowerBoundText)
                        .boundTextModifier()
                    Slider(
                        value: $sliderValue,
                        in: range, step: 1,
                        onEditingChanged: { isDragging in
                            sliderChangedAction(
                                Int(sliderValue)
                            )
                            impactFeedback(style: .soft)
                            withAnimation {
                                isSliderDragging = isDragging
                            }
                        }
                    )
                    .rotationEffect(sliderAngle)
                    Text(upperBoundText)
                        .boundTextModifier()
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(.thinMaterial)
    }
}

private extension LowerPanel {
    var lowerBoundText: String {
        isReversed
        ? "\(Int(range.upperBound))"
        : "\(Int(range.lowerBound))"
    }
    var upperBoundText: String {
        isReversed
        ? "\(Int(range.lowerBound))"
        : "\(Int(range.upperBound))"
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
        isSliderDragging: Binding<Bool>,
        sliderValue: Binding<Float>,
        previews: [Int: String],
        range: ClosedRange<Float>,
        isReversed: Bool,
        fetchAction: @escaping (Int) -> Void
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
                    previews: previews, index: index
                )
                VStack {
                    KFImage(URL(string: url))
                        .placeholder {
                            Placeholder(style: .activity(
                                ratio: Defaults.ImageSize
                                    .previewScale
                            ))
                        }
                        .imageModifier(modifier)
                        .fade(duration: 0.25)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: previewWidth,
                            height: isSliderDragging
                                ? previewHeight : 0
                        )
                    Text("\(index)")
                        .font(isPadWidth ? .callout : .caption)
                        .foregroundColor(
                            index == Int(sliderValue)
                            ? .accentColor : .secondary
                        )
                }
                .onAppear {
                    onImageAppear(index: index)
                }
                .opacity(
                    opacity(index: index)
                )
            }
        }
        .opacity(isSliderDragging ? 1 : 0)
        .padding(.vertical, verticalPadding)
        .frame(
            height: isSliderDragging ? previewHeight
                + verticalPadding * 2 : 0
        )
    }
}

private extension SliderPreivew {
    var verticalPadding: CGFloat {
        isPadWidth ? 30 : 20
    }
    var previewsCount: Int {
        isPadWidth ? isLandscape ? 7 : 5 : 3
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
        previewWidth / Defaults.ImageSize.previewScale
    }
    var previewWidth: CGFloat {
        guard previewsCount > 0 else { return 0 }
        let count = CGFloat(previewsCount)
        let spacing = (count + 1) * previewSpacing
        return (windowW - spacing) / count
    }

    func verify(index: Int) -> Bool {
        index >= Int(range.lowerBound)
            && index <= Int(range.upperBound)
    }
    func opacity(index: Int) -> CGFloat {
        verify(index: index) ? 1 : 0
    }
    func onImageAppear(index: Int) {
        if previews[index] == nil && verify(index: index) {
            fetchAction(index)
        }
    }
}

private extension Text {
    func boundTextModifier() -> some View {
        self.fontWeight(.medium).font(.caption).padding()
    }
}
