//
//  DownloadsView+Subviews.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct DownloadInspectorView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable private var store: StoreOf<DownloadInspectorReducer>
    private let setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<DownloadInspectorReducer>,
        setting: Setting,
        blurRadius: Double,
        tagTranslator: TagTranslator
    ) {
        self.store = store
        self.setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        Group {
            switch store.loadingState {
            case .loading where store.inspection == nil:
                LoadingView()

            case .failed(let error) where store.inspection == nil:
                ErrorView(error: error, action: { store.send(.loadInspection) })

            default:
                List {
                    if let inspection = store.inspection {
                        Section {
                            StaticGalleryDetailCell(
                                gallery: inspection.download.gallery,
                                resolvedCoverURL: inspection.coverURL,
                                setting: setting,
                                translateAction: {
                                    tagTranslator.lookup(
                                        word: $0,
                                        returnOriginal: !setting.translatesTags
                                    )
                                },
                                downloadBadge: inspection.download.badge
                            )
                            .listRowInsets(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                            .listRowBackground(Color.clear)
                        }

                        if !inspection.failedPageIndices.isEmpty || inspection.download.canTriggerUpdate {
                            Section(L10n.Localizable.DownloadsView.Inspector.Section.actions) {
                                if !inspection.failedPageIndices.isEmpty {
                                    Button {
                                        store.send(.retryFailedPages)
                                    } label: {
                                        Label(
                                            L10n.Localizable.DownloadsView.Inspector.Button.retryFailedPages(
                                                inspection.failedPageIndices.count
                                            ),
                                            systemImage: "arrow.clockwise.circle"
                                        )
                                    }
                                }

                                if inspection.download.canTriggerUpdate {
                                    Button {
                                        store.send(.updateDownload)
                                    } label: {
                                        Label(
                                            L10n.Localizable.DownloadsView.Inspector.Button.updateDownload,
                                            systemImage: "arrow.triangle.2.circlepath"
                                        )
                                    }
                                }
                            }
                        }

                        ForEach(DownloadPageStatus.allCases, id: \.self) { status in
                            let pages = inspection.pages.filter { $0.status == status }
                            Section(status.sectionTitle(count: pages.count)) {
                                DownloadInspectorPageGroupRow(
                                    status: status,
                                    pages: pages
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .autoBlur(radius: blurRadius)
        .navigationTitle(L10n.Localizable.DownloadsView.Inspector.Title.downloadStatus)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            CustomToolbarItem(placement: .cancellationAction) {
                Button(L10n.Localizable.EhSettingView.ToolbarItem.Button.done) {
                    dismiss()
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

struct DownloadInspectorPageGroupRow: View {
    let status: DownloadPageStatus
    let pages: [DownloadPageInspection]

    private var pageNumbersText: String {
        let indices = pages.map(\.index).sorted()
        guard !indices.isEmpty else {
            return L10n.Localizable.DownloadsView.Inspector.Page.none
        }
        return Self.formattedPageRanges(indices)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.tint)
                .font(.title3)
                .frame(width: 24)

            Text(pageNumbersText)
                .font(.callout)
                .foregroundStyle(pages.isEmpty ? .secondary : .primary)
                .lineLimit(nil)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private static func formattedPageRanges(_ indices: [Int]) -> String {
        var ranges = [String]()
        var rangeStart: Int?
        var previous: Int?

        func appendCurrentRange() {
            guard let start = rangeStart,
                  let end = previous
            else { return }
            ranges.append(start == end ? "\(start)" : "\(start)-\(end)")
        }

        for index in indices {
            if let last = previous, index == last + 1 {
                previous = index
                continue
            }
            appendCurrentRange()
            rangeStart = index
            previous = index
        }
        appendCurrentRange()

        return ranges.joined(separator: ", ")
    }
}

private extension DownloadPageStatus {
    var title: String {
        switch self {
        case .pending:
            return L10n.Localizable.DownloadsView.Inspector.Status.pending
        case .downloaded:
            return L10n.Localizable.DownloadsView.Inspector.Status.downloaded
        case .failed:
            return L10n.Localizable.DownloadsView.Inspector.Status.failed
        }
    }

    func sectionTitle(count: Int) -> String {
        "\(title) (\(count))"
    }

    var symbolName: String {
        switch self {
        case .pending:
            return "clock"
        case .downloaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending:
            return .secondary
        case .downloaded:
            return .green
        case .failed:
            return .red
        }
    }
}

struct DownloadListRow: View {
    let download: DownloadedGallery
    let setting: Setting
    let tagTranslator: TagTranslator
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            StaticGalleryDetailCell(
                gallery: download.gallery,
                resolvedCoverURL: download.coverURL,
                setting: setting,
                translateAction: {
                    tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
                },
                downloadBadge: download.badge
            )
            .allowsHitTesting(false)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: openAction)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(download.title)
    }
}

struct DownloadInspectorPageRow: View {
    let page: DownloadPageInspection
    let retryAction: () -> Void

    private var symbolName: String {
        switch page.status {
        case .pending:
            return "clock"
        case .downloaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    private var tint: Color {
        switch page.status {
        case .pending:
            return .secondary
        case .downloaded:
            return .green
        case .failed:
            return .red
        }
    }

    private var subtitle: String {
        switch page.status {
        case .pending:
            return L10n.Localizable.DownloadsView.Inspector.Page.pending
        case .downloaded:
            return page.relativePath ?? L10n.Localizable.Struct.DownloadBadge.Text.downloaded
        case .failed:
            return page.failure?.message ?? L10n.Localizable.DownloadsView.Inspector.Page.tapToRetry
        }
    }

    var body: some View {
        Group {
            if page.status == .failed {
                Button(action: retryAction) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Localizable.DownloadsView.Inspector.Page.title(page.index))
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if page.status == .failed {
                Image(systemSymbol: .arrowClockwise)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
