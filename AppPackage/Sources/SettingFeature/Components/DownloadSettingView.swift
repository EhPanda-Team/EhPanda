import SwiftUI
import Resources

struct DownloadSettingView: View {
    @Binding private var downloadThreadLimit: Int
    @Binding private var downloadAllowCellular: Bool
    @Binding private var downloadAutoRetryFailedPages: Bool

    init(
        downloadThreadLimit: Binding<Int>,
        downloadAllowCellular: Binding<Bool>,
        downloadAutoRetryFailedPages: Binding<Bool>
    ) {
        _downloadThreadLimit = downloadThreadLimit
        _downloadAllowCellular = downloadAllowCellular
        _downloadAutoRetryFailedPages = downloadAutoRetryFailedPages
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    LabeledContent(.concurrentImageDownloads) {
                        Text(downloadThreadLimit, format: .number)
                            .monospacedDigit()
                    }
                    Slider(value: downloadThreadLimitValue, in: 1...5, step: 1)
                }
                Toggle(
                    .retryFailedPagesAutomatically,
                    isOn: $downloadAutoRetryFailedPages
                )
            }

            Section {
                Toggle(
                    .allowCellularDownloads,
                    isOn: $downloadAllowCellular
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
            get: { Double(downloadThreadLimit) },
            set: { downloadThreadLimit = Int($0.rounded()) }
        )
    }
}

struct DownloadSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DownloadSettingView(
                downloadThreadLimit: .constant(1),
                downloadAllowCellular: .constant(true),
                downloadAutoRetryFailedPages: .constant(true)
            )
        }
    }
}
