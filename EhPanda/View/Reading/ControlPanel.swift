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
    private let title: String
    private let range: ClosedRange<Float>
    private let previews: [Int: String]
    private let readingDirection: ReadingDirection
    private let settingAction: () -> Void
    private let sliderChangedAction: (Int) -> Void

    init(
        showsPanel: Binding<Bool>,
        sliderValue: Binding<Float>,
        title: String, range: ClosedRange<Float>,
        previews: [Int: String],
        readingDirection: ReadingDirection,
        settingAction: @escaping () -> Void,
        sliderChangedAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _sliderValue = sliderValue
        self.title = title
        self.range = range
        self.previews = previews
        self.readingDirection = readingDirection
        self.settingAction = settingAction
        self.sliderChangedAction = sliderChangedAction
    }

    var body: some View {
        VStack {
            UpperPanel(
                title: title,
                settingAction: settingAction
            )
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            if range.upperBound > range.lowerBound {
                LowerPanel(
                    sliderValue: $sliderValue,
                    previews: previews, range: range,
                    isReversed: readingDirection == .rightToLeft,
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
    private let title: String
    private let settingAction: () -> Void

    init(title: String, settingAction: @escaping () -> Void) {
        self.title = title
        self.settingAction = settingAction
    }

    var body: some View {
        HStack {
            Button(action: dismissAction.callAsFunction) {
                Image(systemName: "chevron.backward")
            }
            .font(.title2)
            .padding(.leading, 20)
            Spacer()
            ZStack {
                Text(title).bold()
                    .lineLimit(1)
                    .padding()
                Slider(value: .constant(0))
                    .opacity(0)
            }
            Spacer()
            Button(action: settingAction) {
                Image(systemName: "gear")
            }
            .font(.title2)
            .padding(.trailing, 20)
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
    private let sliderChangedAction: (Int) -> Void

    init(
        sliderValue: Binding<Float>,
        previews: [Int: String],
        range: ClosedRange<Float>,
        isReversed: Bool,
        sliderChangedAction: @escaping (Int) -> Void
    ) {
        _sliderValue = sliderValue
        self.previews = previews
        self.range = range
        self.isReversed = isReversed
        self.sliderChangedAction = sliderChangedAction
    }

    var body: some View {
        VStack(spacing: 0) {
            SliderPreivew(
                isSliderDragging: $isSliderDragging,
                sliderValue: $sliderValue,
                previews: previews,
                range: range,
                isReversed: isReversed
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

    init(
        isSliderDragging: Binding<Bool>,
        sliderValue: Binding<Float>,
        previews: [Int: String],
        range: ClosedRange<Float>,
        isReversed: Bool
    ) {
        _isSliderDragging = isSliderDragging
        _sliderValue = sliderValue
        self.previews = previews
        self.range = range
        self.isReversed = isReversed
    }

    var body: some View {
        HStack(spacing: previewSpacing) {
            Spacer()
            ForEach(previewsIndices, id: \.self) { index in
                let (url, modifier) =
                PreviewResolver.getPreviewConfigs(
                    previews: previews, index: index
                )
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
                    .opacity(
                        opacity(index: index)
                    )
            }
            Spacer()
        }
        .padding(.vertical, 20).opacity(isSliderDragging ? 1 : 0)
        .frame(height: isSliderDragging ? previewHeight + 40 : 0)
    }
}

private extension SliderPreivew {
    var previewsCount: Int {
        isPadWidth ? 5 : 3
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

    func opacity(index: Int) -> CGFloat {
        let outOfRange = index < Int(range.lowerBound)
            || index > Int(range.upperBound)
        return outOfRange ? 0 : 1
    }
}

private extension Text {
    func boundTextModifier() -> some View {
        self.fontWeight(.medium).font(.caption).padding()
    }
}
