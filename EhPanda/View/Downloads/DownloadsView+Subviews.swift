//
//  DownloadsView+Subviews.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct DownloadInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            GalleryDetailCell(
                                gallery: inspection.download.gallery,
                                coverSource: .static(inspection.coverURL),
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

                        Section {
                            ForEach(DownloadPageStatus.inspectorSummaryOrder, id: \.self) { status in
                                let pages = inspection.pages.filter { $0.status == status }
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
                        Section(L10n.Localizable.DownloadsView.Inspector.Section.actions) {
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
                                    L10n.Localizable.DownloadsView.Inspector.Button.retryFailedPages,
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
        .autoBlur(radius: blurRadius)
        .progressHUD(
            config: store.hudConfig,
            unwrapping: $store.route,
            case: \.hud
        )
        .navigationTitle(L10n.Localizable.DownloadsView.Inspector.Title.downloadStatus)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close, action: dismiss.callAsFunction)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

private struct DownloadInspectorValidationActionLabel: View {
    let isValidating: Bool
    let isDisabled: Bool
    let reduceMotion: Bool

    private var title: String {
        isValidating
            ? L10n.Localizable.DownloadsView.Inspector.Button.validatingImageData
            : L10n.Localizable.DownloadsView.Button.validateImageData
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    var body: some View {
        HStack {
            Label(title, systemSymbol: .checkmarkShield)
            Spacer(minLength: 12)
            ZStack {
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.85))
                        )
                }
            }
            .frame(width: 20, height: 20)
        }
        .disabledActionForegroundStyle(isDisabled)
        .animation(progressAnimation, value: isValidating)
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
            return L10n.Localizable.DownloadsView.Inspector.Page.none
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

    func summaryTitle(count: Int) -> String {
        "\(title) (\(count))"
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
        case .downloaded: .green
        case .failed: .red
        }
    }
}

private extension DownloadedGallery {
    var inspectorPauseResumeTitle: String {
        displayStatus == .inactive
            ? L10n.Localizable.DownloadsView.Swipe.Button.resume
            : L10n.Localizable.DownloadsView.Swipe.Button.pause
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

struct DownloadListRow: View {
    let download: DownloadedGallery
    let setting: Setting
    let tagTranslator: TagTranslator
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            GalleryDetailCell(
                gallery: download.gallery,
                coverSource: .static(download.coverURL),
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
