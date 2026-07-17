import SwiftUI
import AppModels
import Sharing
import Resources

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
                    Slider(value: downloadThreadLimitValue, in: 1...5, step: 1)
                }
                Toggle(
                    .retryFailedPagesAutomatically,
                    isOn: Binding($setting.downloadAutoRetryFailedPages)
                )
            }

            Section {
                Toggle(
                    .allowCellularDownloads,
                    isOn: Binding($setting.downloadAllowCellular)
                )
            } header: {
                Text(.network)
            } footer: {
                Text(.networkDescription)
            }
        }
        .navigationTitle(.title)
    }

    private var downloadThreadLimitValue: Binding<Double> {
        .init(
            get: { Double(setting.downloadThreadLimit) },
            set: { newValue in $setting.withLock { $0.downloadThreadLimit = Int(newValue.rounded()) } }
        )
    }
}

struct DownloadSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DownloadSettingView()
        }
    }
}
