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
    private let currentIndex: Int
    private let range: ClosedRange<Float>
    private let previews: [Int: String]
    private let readingDirection: ReadingDirection
    private let settingAction: () -> Void
    private let fetchAction: (Int) -> Void
    private let sliderChangedAction: (Int) -> Void

    init(
        showsPanel: Binding<Bool>,
        sliderValue: Binding<Float>,
        currentIndex: Int,
        range: ClosedRange<Float>,
        previews: [Int: String],
        readingDirection: ReadingDirection,
        settingAction: @escaping () -> Void,
        fetchAction: @escaping (Int) -> Void,
        sliderChangedAction: @escaping (Int) -> Void
    ) {
        _showsPanel = showsPanel
        _sliderValue = sliderValue
        self.currentIndex = currentIndex
        self.range = range
        self.previews = previews
        self.readingDirection = readingDirection
        self.settingAction = settingAction
        self.fetchAction = fetchAction
        self.sliderChangedAction = sliderChangedAction
    }

    var body: some View {
        VStack {
            UpperPanel(
                title: "\(currentIndex) / \(Int(range.upperBound))",
                settingAction: settingAction
            )
            .offset(y: showsPanel ? 0 : -50)
            Spacer()
            if range.upperBound > range.lowerBound {
                LowerPanel(
                    sliderValue: $sliderValue,
                    previews: previews, range: range,
                    isReversed: readingDirection == .rightToLeft,
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
                        .foregroundColor(.secondary)
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
