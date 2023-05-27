//
//  ReadingSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/18.
//

import SwiftUI
import ComposableArchitecture

struct ReadingSettingView: View {
    @Binding private var readingDirection: ReadingDirection
    @Binding private var prefetchLimit: Int
    @Binding private var enablesLandscape: Bool
    @Binding private var contentDividerHeight: Double
    @Binding private var maximumScaleFactor: Double
    @Binding private var doubleTapScaleFactor: Double

    init(
        readingDirection: Binding<ReadingDirection>, prefetchLimit: Binding<Int>,
        enablesLandscape: Binding<Bool>, contentDividerHeight: Binding<Double>,
        maximumScaleFactor: Binding<Double>, doubleTapScaleFactor: Binding<Double>
    ) {
        _readingDirection = readingDirection
        _prefetchLimit = prefetchLimit
        _enablesLandscape = enablesLandscape
        _contentDividerHeight = contentDividerHeight
        _maximumScaleFactor = maximumScaleFactor
        _doubleTapScaleFactor = doubleTapScaleFactor
    }

    var body: some View {
        Form {
            Section {
                Picker(L10n.Localizable.ReadingSettingView.Title.direction, selection: $readingDirection) {
                    ForEach(ReadingDirection.allCases) {
                        Text($0.value).tag($0)
                    }
                }
                .pickerStyle(.menu)
                Picker(L10n.Localizable.ReadingSettingView.Title.preloadLimit, selection: $prefetchLimit) {
                    ForEach(Array(stride(from: 6, through: 18, by: 4)), id: \.self) { value in
                        Text(L10n.Localizable.Common.Value.pages("\(value)")).tag(value)
                    }
                }
                .pickerStyle(.menu)
                if !DeviceUtil.isPad {
                    Toggle(L10n.Localizable.ReadingSettingView.Title.enablesLandscape, isOn: $enablesLandscape)
                }
            }
            Section(L10n.Localizable.ReadingSettingView.Section.Title.appearance) {
                Picker(
                    L10n.Localizable.ReadingSettingView.Title.separatorHeight,
                    selection: $contentDividerHeight
                ) {
                    ForEach(Array(stride(from: 0, through: 20, by: 5)), id: \.self) { value in
                        Text("\(value)pt").tag(Double(value))
                    }
                }
                .pickerStyle(.menu)
                .disabled(readingDirection != .vertical)
                ScaleFactorRow(
                    scaleFactor: $maximumScaleFactor,
                    labelContent: L10n.Localizable.ReadingSettingView.Title.maximumScaleFactor,
                    minFactor: 1.5, maxFactor: 10
                )
                ScaleFactorRow(
                    scaleFactor: $doubleTapScaleFactor,
                    labelContent: L10n.Localizable.ReadingSettingView.Title.doubleTapScaleFactor,
                    minFactor: 1.5, maxFactor: 5
                )
            }
        }
        .navigationTitle(L10n.Localizable.ReadingSettingView.Title.reading)
    }
}

private struct ScaleFactorRow: View {
    @Binding private var scaleFactor: Double
    private let labelContent: String
    private let minFactor: Double
    private let maxFactor: Double

    init(
        scaleFactor: Binding<Double>, labelContent: String,
        minFactor: Double, maxFactor: Double
    ) {
        _scaleFactor = scaleFactor
        self.labelContent = labelContent
        self.minFactor = minFactor
        self.maxFactor = maxFactor
    }

    var body: some View {
        VStack {
            HStack {
                Text(labelContent)
                Spacer()
                Text("\(scaleFactor.roundedString())x").foregroundStyle(.tint)
            }
            Slider(
                value: $scaleFactor, in: minFactor...maxFactor, step: 0.5,
                minimumValueLabel: Text("\(minFactor.roundedString())x")
                    .fontWeight(.medium).font(.callout),
                maximumValueLabel: Text("\(maxFactor.roundedString())x")
                    .fontWeight(.medium).font(.callout),
                label: EmptyView.init
            )
        }
        .padding(.vertical, 10)
    }
}

private extension Double {
    func roundedString() -> String {
        roundedString(with: 1)
    }

    func roundedString(with places: Int) -> String {
        String(format: "%.\(places)f", self)
    }
}

struct ReadingSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ReadingSettingView(
                readingDirection: .constant(.vertical),
                prefetchLimit: .constant(10),
                enablesLandscape: .constant(false),
                contentDividerHeight: .constant(0),
                maximumScaleFactor: .constant(3),
                doubleTapScaleFactor: .constant(2)
            )
        }
    }
}
