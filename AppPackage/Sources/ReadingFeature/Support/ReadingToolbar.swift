import AppComponents
import AppModels
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

struct ReadingToolbar: ToolbarContent {
    @Binding var setting: Setting
    @Binding var enablesLiveText: Bool
    let autoPlayHandler: AutoPlayHandler
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
        // The toolbar is handed the title rather than a view of its own reading the page: in a toolbar item, such a
        // view was measured (2026-11-03, iOS 27) to keep showing a page after the reader had left it.
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
                Label {
                    Text(.liveText)
                } icon: {
                    Image(systemSymbol: .translate)
                        .symbolRenderingMode(enablesLiveText ? .palette : .monochrome)
                        .foregroundStyle(.primary, Color.accentColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: enablesLiveText)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
            }
            // The automatic toolbar button style renders the symbol without its pulse.
            .buttonStyle(.plain)
            .accessibilityAddTraits(enablesLiveText ? .isSelected : [])
        }
        if isLandscape {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle(isOn: $setting.usesHorizontalDualPages) {
                        Text(.dualPageMode)
                    }
                    Toggle(isOn: $setting.exceptCover) {
                        Text(.showCoverAlone)
                    }
                    .disabled(!setting.usesHorizontalDualPages)
                } label: {
                    Label(.dualPageMode, systemSymbol: .rectangleSplit2x1)
                        .symbolVariant(setting.usesHorizontalDualPages ? .fill : .none)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            AutoPlayMenu(handler: autoPlayHandler)
        }
        ToolbarOverflowMenu {
            Button(action: retryAllFailedImagesAction) {
                Label(.retryAllFailedImages, systemSymbol: .exclamationmarkArrowTrianglehead2ClockwiseRotate90)
            }
            Button(action: reloadAllImagesAction) {
                Label(.reloadAllImages, systemSymbol: .arrowCounterclockwise)
            }
            Button(action: navigateSettingAction) {
                Label(.readingSettings, systemSymbol: .gear)
            }
        }
    }
}

/// The Auto-Play menu. Every page turn re-evaluates the toolbar, as it is handed the page's title.
/// The menu's one input is the handler, so those evaluations leave it as it is and it is redrawn only
/// when the policy changes: an open menu is not rebuilt under a reader's finger, which could lose a
/// tap on Off made during auto-play.
private struct AutoPlayMenu: View {
    let handler: AutoPlayHandler

    var body: some View {
        @Bindable var handler = handler
        Menu {
            Picker(selection: $handler.policy) {
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
}
