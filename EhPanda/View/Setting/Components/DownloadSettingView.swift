//
//  DownloadSettingView.swift
//  EhPanda
//

import SwiftUI

struct DownloadSettingView: View {
    @Binding private var downloadThreadMode: DownloadThreadMode
    @Binding private var downloadAllowCellular: Bool
    @Binding private var downloadAutoRetryFailedPages: Bool

    init(
        downloadThreadMode: Binding<DownloadThreadMode>,
        downloadAllowCellular: Binding<Bool>,
        downloadAutoRetryFailedPages: Binding<Bool>
    ) {
        _downloadThreadMode = downloadThreadMode
        _downloadAllowCellular = downloadAllowCellular
        _downloadAutoRetryFailedPages = downloadAutoRetryFailedPages
    }

    var body: some View {
        Form {
            Section(L10n.Localizable.DownloadSettingView.Section.Title.downloadQueue) {
                Picker(
                    L10n.Localizable.DownloadSettingView.Title.concurrentImageDownloads,
                    selection: $downloadThreadMode
                ) {
                    ForEach(DownloadThreadMode.allCases) {
                        Text($0.value).tag($0)
                    }
                }
                .pickerStyle(.menu)
                Toggle(
                    L10n.Localizable.DownloadSettingView.Title.retryFailedPagesAutomatically,
                    isOn: $downloadAutoRetryFailedPages
                )
            }

            Section {
                Toggle(
                    L10n.Localizable.DownloadSettingView.Title.allowCellularDownloads,
                    isOn: $downloadAllowCellular
                )
            } header: {
                Text(L10n.Localizable.DownloadSettingView.Section.Title.network)
            } footer: {
                Text(L10n.Localizable.DownloadSettingView.Footer.network)
            }
        }
        .navigationTitle(L10n.Localizable.DownloadsView.Title.downloads)
    }
}

struct DownloadSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DownloadSettingView(
                downloadThreadMode: .constant(.single),
                downloadAllowCellular: .constant(true),
                downloadAutoRetryFailedPages: .constant(true)
            )
        }
    }
}
