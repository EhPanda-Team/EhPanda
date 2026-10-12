import AppComponents
import AppModels
import Resources
import Sharing
import SwiftUI

struct DownloadSettingView: View {
    @Shared(.setting) private var setting: Setting

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    LabeledContent(.concurrentImageDownloads) {
                        Text(setting.downloadThreadLimit, format: .number)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(setting.downloadThreadLimit)))
                            .animation(.default, value: setting.downloadThreadLimit)
                    }
                    Slider(value: Binding($setting.downloadThreadLimitSliderValue), in: 1...5, step: 1)
                }
                AppToggle(
                    .retryFailedPagesAutomatically,
                    isOn: Binding($setting.downloadAutoRetryFailedPages)
                )
            }

            Section {
                AppToggle(
                    .allowCellularDownloads,
                    isOn: Binding($setting.downloadAllowCellular)
                )
            } header: {
                Text(.network)
            } footer: {
                Text(.networkDescription)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(.title)
    }
}

extension Setting {
    /// The concurrent download limit as the slider's value, which steps through whole numbers.
    var downloadThreadLimitSliderValue: Double {
        get { Double(downloadThreadLimit) }
        set { downloadThreadLimit = Int(newValue.rounded()) }
    }
}

#Preview("Initial") {
    NavigationStack {
        DownloadSettingView()
    }
}
