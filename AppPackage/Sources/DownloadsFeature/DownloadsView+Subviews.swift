import AppComponents
import AppModels
import ComposableArchitecture
import GalleryListComponents
import Resources
import SFSafeSymbols
import SwiftUI
import SystemNotification
import TagTranslationFeature

struct DownloadInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable private var store: StoreOf<DownloadInspectorReducer>

    init(store: StoreOf<DownloadInspectorReducer>) {
        self.store = store
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
                            GalleryDetailCell(
                                gallery: inspection.download.gallery,
                                coverSource: .static(inspection.coverURL),
                                translateAction: {
                                    store.tagTranslator.lookup(
                                        word: $0,
                                        returnOriginal: !store.setting.translateTags
                                    )
                                },
                                downloadBadge: inspection.download.badge
                            )
                            .listRowInsets(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(DownloadPageStatus.inspectorSummaryOrder, id: \.self) { status in
                                let pages = inspection.pages.filter({ $0.status == status })
                                DownloadInspectorPageGroupRow(
                                    status: status,
                                    pages: pages
                                )
                            }
                        }

                        let isPauseResumeDisabled = !inspection.download.canTogglePause
                        let isRetryFailedPagesDisabled = !inspection.canRetryFailedPages
                        let isValidateImageDataDisabled =
                            !inspection.canValidateImageData || store.isValidatingImageData
                        Section(.actions) {
                            Button {
                                store.send(.toggleDownloadPause)
                            } label: {
                                Label(
                                    inspection.download.inspectorPauseResumeTitle,
                                    systemSymbol: inspection.download.inspectorPauseResumeSymbol
                                )
                                .disabledActionForegroundStyle(isPauseResumeDisabled)
                            }
                            .disabled(isPauseResumeDisabled)

                            Button {
                                store.send(.retryPages(inspection.failedPageIndices))
                            } label: {
                                Label(
                                    .retryFailedPages,
                                    systemSymbol: .arrowClockwise
                                )
                                .disabledActionForegroundStyle(isRetryFailedPagesDisabled)
                            }
                            .disabled(isRetryFailedPagesDisabled)

                            Button {
                                store.send(.validateImageData)
                            } label: {
                                DownloadInspectorValidationActionLabel(
                                    isValidating: store.isValidatingImageData,
                                    isDisabled: isValidateImageDataDisabled,
                                    reduceMotion: reduceMotion
                                )
                            }
                            .disabled(isValidateImageDataDisabled)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toast($store.scope(\.$toast, action: \.toast))
        .navigationTitle(.downloadStatus)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: dismiss.callAsFunction)
            }
        }
    }
}

private struct DownloadInspectorValidationActionLabel: View {
    let isValidating: Bool
    let isDisabled: Bool
    let reduceMotion: Bool

    private var title: LocalizedStringResource {
        isValidating
            ? .validatingImageData
            : .validateImageData
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    var body: some View {
        HStack {
            Label(title, systemSymbol: .checkmarkShield)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProgressView()
                .controlSize(.small)
                .animation(.default) {
                    $0
                        .opacity(isValidating ? 1 : 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
                .frame(width: 20, height: 20)
        }
        .disabledActionForegroundStyle(isDisabled)
    }
}

struct DownloadInspectorPageGroupRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let status: DownloadPageStatus
    let pages: [DownloadPageInspection]

    private var countAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    private var pageNumbersText: String {
        let indices = pages.map(\.index).sorted()
        guard !indices.isEmpty else {
            return String(localized: .noPages)
        }
        return Self.formattedPageRanges(indices)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemSymbol: status.symbol)
                .foregroundStyle(status.tintColor)
                .font(.title3)
                .labelReservedIconWidth(24)

            VStack(alignment: .leading, spacing: 3) {
                Text(status.summaryTitle(count: pages.count))
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(countAnimation, value: pages.count)

                Text(pageNumbersText)
                    .font(.callout)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(pages.isEmpty ? .secondary : .primary)
                    .lineLimit(nil)
                    .textSelection(.enabled)
                    .animation(countAnimation, value: pageNumbersText)
            }
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
    static let inspectorSummaryOrder: [Self] = [
        .downloaded,
        .pending,
        .failed
    ]

    func summaryTitle(count: Int) -> LocalizedStringResource {
        switch self {
        case .pending:
            return .pending(count: count)
        case .downloaded:
            return .downloaded(count: count)
        case .failed:
            return .failed(count: count)
        }
    }

    var symbol: SFSymbol {
        switch self {
        case .pending: .clock
        case .downloaded: .checkmarkCircle
        case .failed: .exclamationmarkCircle
        }
    }

    var tintColor: Color {
        switch self {
        case .pending: .primary
        case .downloaded: .accentColor
        case .failed: .red
        }
    }
}

private extension DownloadedGallery {
    var inspectorPauseResumeTitle: LocalizedStringResource {
        displayStatus == .inactive
            ? .resume
            : .pause
    }

    var inspectorPauseResumeSymbol: SFSymbol {
        displayStatus == .inactive ? .playFill : .pauseFill
    }
}

private extension View {
    @ViewBuilder
    func disabledActionForegroundStyle(_ isDisabled: Bool) -> some View {
        if isDisabled {
            foregroundStyle(.secondary)
        } else {
            self
        }
    }
}

// MARK: DownloadInspectorView Previews
private func previewInspection(
    displayStatus: DownloadDisplayStatus,
    downloaded: [Int] = [],
    pending: [Int] = [],
    failed: [Int] = []
) -> DownloadInspection {
    let groups: [(status: DownloadPageStatus, pages: [Int])] = [
        (.downloaded, downloaded), (.pending, pending), (.failed, failed)
    ]
    // A page counts as complete in the manifest only when its relative path is non-empty, so the
    // header cell's badge stays consistent with the page groups listed underneath it.
    let manifestPages = groups.reduce(into: [Int: String]()) { result, group in
        for page in group.pages {
            result[page] = group.status == .downloaded ? "\(page).jpg" : ""
        }
    }
    return .init(
        download: .init(
            manifest: .init(
                gid: "1", host: .ehentai, token: "", title: "Sample Download", jpnTitle: nil,
                category: .doujinshi, language: .english, remoteCoverURL: nil,
                uploader: "Anonymous", tags: [], postedDate: .now, rating: 4.5,
                pages: manifestPages
            ),
            folderURL: .mock, folderName: "[1] Sample Download",
            localCoverURL: nil, localPageURLs: [:], modificationDate: .now,
            displayStatus: displayStatus
        ),
        pages: groups
            .flatMap { group in
                group.pages.map({ DownloadPageInspection(index: $0, status: group.status) })
            }
            .sorted(by: { $0.index < $1.index })
    )
}

// The empty `gid` is load-bearing: `onPresented` bails out on it, so the hand-built inspection below
// survives instead of being replaced by a client fetch. Previews never send it anyway — the store is
// built here rather than presented by `DownloadsReducer` — but the guard keeps that independent.
@MainActor private func previewInspectorStore(
    inspection: DownloadInspection?,
    loadingState: LoadingState = .idle,
    isValidatingImageData: Bool = false
) -> StoreOf<DownloadInspectorReducer> {
    .init(
        initialState: {
            var state = DownloadInspectorReducer.State()
            state.inspection = inspection
            state.loadingState = loadingState
            state.isValidatingImageData = isValidatingImageData
            return state
        }(),
        reducer: DownloadInspectorReducer.init
    )
}

#Preview("Downloading") {
    NavigationStack {
        DownloadInspectorView(
            store: previewInspectorStore(
                inspection: previewInspection(
                    displayStatus: .active,
                    downloaded: Array(1...12),
                    pending: Array(13...20) + [22],
                    failed: [21, 23, 24]
                )
            )
        )
    }
}

#Preview("Completed") {
    NavigationStack {
        DownloadInspectorView(
            store: previewInspectorStore(
                inspection: previewInspection(displayStatus: .completed, downloaded: Array(1...24))
            )
        )
    }
}

#Preview("Validating") {
    NavigationStack {
        DownloadInspectorView(
            store: previewInspectorStore(
                inspection: previewInspection(displayStatus: .completed, downloaded: Array(1...24)),
                isValidatingImageData: true
            )
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        DownloadInspectorView(
            store: previewInspectorStore(inspection: nil, loadingState: .loading)
        )
    }
}

#Preview("Load failed") {
    NavigationStack {
        DownloadInspectorView(
            store: previewInspectorStore(inspection: nil, loadingState: .failed(.notFound))
        )
    }
}

struct DownloadListRow: View {
    @SharedReader(.tagTranslator) private var tagTranslator: TagTranslator
    @SharedReader(.setting) private var setting: Setting
    let download: DownloadedGallery
    let openAction: () -> Void

    var body: some View {
        GalleryDetailCell(
            gallery: download.gallery,
            coverSource: .static(download.coverURL),
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translateTags)
            },
            downloadBadge: download.badge
        )
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: openAction)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(download.title)
    }
}
