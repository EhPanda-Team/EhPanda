import AppComponents
import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

struct ReadingToolbar: ToolbarContent {
    @Binding var setting: Setting
    @Binding var enablesLiveText: Bool
    @Binding var autoPlayPolicy: AutoPlayPolicy
    let title: String
    let isLandscape: Bool
    let dismissAction: () -> Void
    let navigateSettingAction: () -> Void
    let reloadAllImagesAction: () -> Void
    let retryAllFailedImagesAction: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: dismissAction) {
                Label(.close, systemSymbol: .xmark)
            }
        }
        .visibilityPriority(.high)
        // Leading in every size class, never `.title`: the bar leaves a `.title` item out of its visibility-priority
        // overflow and drops it outright when it does not fit, as in a narrow iPad window whose window controls take
        // the leading edge. Here, at high priority, it stays and the automatic-priority actions overflow instead.
        ToolbarItem(placement: .topBarLeading) {
            Text(title)
                .font(.headline)
                // The leading slot proposes less width than the text needs, which would wrap the digits.
                .fixedSize(horizontal: true, vertical: false)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityIdentifier("reading_page_indicator")
                .animation(.default, value: title)
                .padding(.horizontal, 12)
                // Match the native toolbar glass height while allowing taller content to grow.
                .frame(minHeight: 44)
                .glassEffect(.regular)
        }
        .sharedBackgroundVisibility(.hidden)
        .visibilityPriority(.high)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                enablesLiveText.toggle()
            } label: {
                Label(.liveText, systemSymbol: .translate)
                    .symbolVariant(enablesLiveText ? .fill : .none)
            }
        }
        if isLandscape && setting.readingDirection != .vertical {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle(isOn: $setting.enableDualPageMode) {
                        Text(.dualPageMode)
                    }
                    Toggle(isOn: $setting.exceptCover) {
                        Text(.exceptTheCover)
                    }
                    .disabled(!setting.enableDualPageMode)
                } label: {
                    Label(.dualPageMode, systemSymbol: .rectangleSplit2x1)
                        .symbolVariant(setting.enableDualPageMode ? .fill : .none)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: $autoPlayPolicy) {
                    ForEach(AutoPlayPolicy.allCases) { policy in
                        Text(policy.value).tag(policy)
                    }
                } label: {
                    Text(.autoPlay)
                }
                .pickerStyle(.inline)
            } label: {
                Label(.autoPlay, systemSymbol: .timer)
            }
        }
        ToolbarOverflowMenu {
            Button(action: retryAllFailedImagesAction) {
                Label(.retryAllFailedImages, systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
            }
            Button(action: reloadAllImagesAction) {
                Label(.reloadAllImages, systemSymbol: .arrowCounterclockwise)
            }
            Button(action: navigateSettingAction) {
                Label(.readingSetting, systemSymbol: .gear)
            }
        }
    }
}
