import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import Sharing
import SwiftUI

// MARK: HeaderSection
struct HeaderSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @SharedReader(.didLogin) private var didLogin: Bool
    @SharedReader(.user) var user: User
    @SharedReader(.setting) private var setting: Setting

    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let downloadBadge: DownloadBadge?
    let downloadNeedsRepair: Bool
    let downloadFolders: [String]
    let isPreparingDownload: Bool
    let canDownload: Bool
    let displayJapaneseTitle: Bool
    let showFullTitle: Bool
    let showFullTitleAction: () -> Void
    let downloadAction: () -> Void
    let downloadToFolderAction: (String) -> Void
    let manageFoldersAction: () -> Void
    let createDefaultFolderAction: () -> Void
    let favorAction: (Int) -> Void
    let unfavorAction: () -> Void
    let navigateReadingAction: () -> Void
    let navigateUploaderAction: () -> Void

    // 32pt at default (.large); scales on the same metric as the symbol it holds, so the glass
    // circle grows exactly as fast as the glyph inside it. A fixed size here let the symbol outgrow
    // its own background and spill outside the circle at accessibility sizes.
    @ScaledMetric(relativeTo: .callout) private var actionIconButtonSize: CGFloat = 32
    // 16pt at default (.large); scales with Dynamic Type relative to the nearest text style (.callout, 16pt).
    @ScaledMetric(relativeTo: .callout) private var actionIconFontSize: CGFloat = 16
    private var actionIconFont: Font { .system(size: actionIconFontSize, weight: .semibold) }
    // 10pt at default (.large); scales with Dynamic Type relative to the nearest text style (.caption2, 11pt).
    @ScaledMetric(relativeTo: .caption2) private var progressCenterSymbolSize: CGFloat = 10
    // 2.5pt / 3pt at default (.large). The ring is drawn inside the download button, so it scales on
    // the button's own metric: held at their literal values a 2.5pt stroke inset by 3pt reads as a
    // hairline hugging the rim once the button is three times wider.
    @ScaledMetric(relativeTo: .callout) private var progressRingLineWidth: CGFloat = 2.5
    @ScaledMetric(relativeTo: .callout) private var progressRingInset: CGFloat = 3

    private var title: String {
        let normalTitle = galleryDetail.title
        return displayJapaneseTitle ? galleryDetail.jpnTitle ?? normalTitle : normalTitle
    }
    private var showsMetadataPreparation: Bool { isPreparingDownload && downloadBadge == nil }
    private var isDownloadActionDisabled: Bool {
        guard canDownload else { return true }
        return isPreparingDownload
    }
    private var downloadButtonTint: Color {
        switch downloadBadge?.status {
        case .updateAvailable: return .orange
        case .completed: return .red
        case .error: return isPartialDownloadError ? .orange : .red
        default: return .accentColor
        }
    }
    private var isPartialDownloadError: Bool {
        guard let badge = downloadBadge, badge.status == .error else { return false }
        return badge.progress.completedPageCount > 0
            && badge.progress.completedPageCount < badge.progress.pageCount
    }
    /// The badge carries no line cap of its own: `CategoryLabel` keeps the designed single line at
    /// and below the default size and lets a name wrap inside the badge above it, and this site
    /// follows that one policy rather than overriding it. The vocabulary is eleven fixed names, so
    /// a wrapped badge is at most two short lines, and here the cap would never have engaged anyway
    /// (see below).
    ///
    /// The 0.72 shrink-to-fit factor that used to accompany that cap is gone (D-14). A shrink can
    /// only engage where the badge is offered less width than it asked for, and at the default size
    /// it never is: the horizontal candidate of ``bottomActionRow`` is picked only when every
    /// member's *ideal* width already fits, and the vertical candidate hands the badge the whole
    /// text column, several times wider than the longest category name drawn at `.headline`. Above
    /// the default size the row grows instead — shrinking text the reader deliberately enlarged is
    /// the answer this phase removes everywhere, not the one to keep at its last site.
    private var categoryLabel: some View {
        CategoryLabel(
            text: gallery.category.value, color: gallery.color(host: setting.galleryHost), textStyle: .headline,
            insets: .init(top: 2, leading: 4, bottom: 2, trailing: 4), cornerRadius: 3
        )
    }
    private var downloadButton: some View {
        Group {
            if let progress = activeDownloadProgress {
                Button(action: downloadAction) {
                    progressIndicator(
                        progress: progress,
                        isDeterminate: true,
                        centerSymbol: activeDownloadIconSymbol
                    )
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
            } else if let progress = queuedDownloadProgress {
                Button(action: downloadAction) {
                    progressIndicator(
                        progress: progress,
                        isDeterminate: false,
                        centerSymbol: activeDownloadIconSymbol
                    )
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
            } else if downloadBadge == nil {
                Menu {
                    Section {
                        Button(action: manageFoldersAction) {
                            Label(
                                .RLocalizable.manageFolders,
                                systemSymbol: .folderBadgeGearshape
                            )
                        }
                        // Without any folder there is nowhere to download to, so offer a
                        // one-tap shortcut to bootstrap one instead of forcing a trip
                        // through the folder manager.
                        if downloadFolders.isEmpty {
                            Button(action: createDefaultFolderAction) {
                                Label(
                                    .createDefaultFolder,
                                    systemSymbol: .folderBadgePlus
                                )
                            }
                            .menuActionDismissBehavior(.disabled)
                        }
                    }
                    Section {
                        if downloadFolders.isEmpty {
                            Text(.noFolders)
                        } else {
                            ForEach(downloadFolders, id: \.self) { folder in
                                Button {
                                    downloadToFolderAction(folder)
                                } label: {
                                    Label(folder, systemSymbol: .folder)
                                }
                            }
                        }
                    }
                } label: {
                    downloadIconLabel
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
                .animation(
                    showsMetadataPreparation
                        ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                    value: showsMetadataPreparation
                )
            } else {
                Button(action: downloadAction) {
                    downloadIconLabel
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
            }
        }
        .disabled(isDownloadActionDisabled)
        .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        .accessibilityLabel(downloadButtonAccessibilityLabel)
    }
    private var downloadIconLabel: some View {
        Image(systemSymbol: downloadIconSymbol)
            .font(actionIconFont)
            .foregroundStyle(canDownload ? downloadButtonTint : .secondary)
            .rotationEffect(.degrees(showsMetadataPreparation ? 360 : 0))
            .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            .contentShape(.circle)
    }
    private var favoriteButton: some View {
        Menu {
            ForEach(0..<10) { index in
                Button(user.getFavoriteCategory(index: index)) { favorAction(index) }
            }
        } label: {
            // The title is the menu's VoiceOver label and its Voice Control name; the heart alone
            // had neither. The favourited state is the overlaid `Label` below, swapped in by
            // visibility, so the state travels as which control is present, not as label text.
            Label(.accessibilityAddToFavorites, systemSymbol: .heart)
                .labelStyle(.iconOnly)
                .font(actionIconFont)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
        .animation(.default) {
            $0.visible(!galleryDetail.isFavorited)
        }
        .overlay {
            Button(action: unfavorAction) {
                Label(.favorited, systemSymbol: .heartFill)
                    .labelStyle(.iconOnly)
                    .font(actionIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            .animation(.default) {
                $0.visible(galleryDetail.isFavorited)
            }
        }
        .buttonStyle(.glass(.regular.interactive()))
        .buttonBorderShape(.circle)
        .tint(.accentColor)
        .disabled(!didLogin)
    }
    private var readButton: some View {
        Button(action: navigateReadingAction) {
            Label(.read, systemSymbol: .bookFill)
                .labelStyle(.iconOnly)
                .font(actionIconFont)
                .foregroundStyle(.white)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
    }
    private func progressIndicator(
        progress: Double, isDeterminate: Bool, centerSymbol: SFSymbol
    ) -> some View {
        Circle()
            .stroke(downloadButtonTint.opacity(0.18), lineWidth: progressRingLineWidth)
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(downloadButtonTint, style: .init(lineWidth: progressRingLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.default, value: progress)
            }
            .padding(progressRingInset)
            .animation(.default) {
                $0.visible(isDeterminate)
            }
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(downloadButtonTint)
                    .controlSize(.small)
                    .animation(.default) {
                        $0.visible(!isDeterminate)
                    }
            }
            .overlay {
                // Decorative: the enclosing button already announces the status and the action
                // through `downloadButtonAccessibilityLabel`, so the glyph would only be read twice.
                Image(systemSymbol: centerSymbol)
                    .font(.system(size: progressCenterSymbolSize, weight: .semibold))
                    .foregroundStyle(downloadButtonTint)
                    .accessibilityHidden(true)
            }
            .frame(width: actionIconButtonSize, height: actionIconButtonSize)
    }
    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                downloadButton
                favoriteButton
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    downloadButton
                    favoriteButton
                }
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .trailing, spacing: 6) {
                downloadButton
                favoriteButton
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
    }
    private var bottomActionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                categoryLabel.frame(maxWidth: .infinity, alignment: .leading)
                actionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                categoryLabel

                actionButtons
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    private var queuedDownloadProgress: Double? {
        downloadBadge?.status == .queued ? 0 : nil
    }
    private var activeDownloadProgress: Double? {
        guard let badge = downloadBadge,
              [.active, .inactive].contains(badge.status)
        else { return nil }
        return badge.progress.fraction
    }
    private var activeDownloadIconSymbol: SFSymbol {
        switch downloadBadge?.status {
        case .inactive: return .playFill
        case .active: return .pauseFill
        default: return downloadIconSymbol
        }
    }
    /// Three lines at every size until the reader expands the title, then none — the designed
    /// behaviour, restored (owner decision, 2026-09-03).
    ///
    /// This site was briefly uncapped above the default size, on the reading that a title losing
    /// its tail as the text grows is information taken away. It is not, here: the cap comes with a
    /// remedy in the same place, since the title *is* the button that expands it, at every size.
    /// What the uncapped title cost instead was the rest of the header — a long one filled the
    /// screen on its own and pushed the uploader, the category and the three actions off it — and
    /// nothing was gained, because the expansion the reader could already ask for had nothing left
    /// to reveal. Same budget at the default size as ever, so parity is untouched; the folding is a
    /// deliberate design, not a truncation this phase should remove (see the thumbnail cell's own
    /// budget under D-01's round-II directions for the parallel case).
    private var titleLineLimit: Int? {
        showFullTitle ? nil : 3
    }

    /// The uploader is a user-authored name occupying a line of its own, so above the default size
    /// it wraps onto a second line rather than ellipsising; at and below it the designed single line
    /// is kept.
    private var uploaderLineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }

    private var downloadIconSymbol: SFSymbol {
        switch downloadBadge?.status {
        case .completed: return .trash
        case .updateAvailable: return .arrowTrianglehead2ClockwiseRotate90
        case .error:
            return downloadNeedsRepair
                ? .wrenchAndScrewdriver
                : .exclamationmarkCircle
        case .inactive: return .playFill
        default: return .icloudAndArrowDown
        }
    }

    @GalleryCoverMetrics(.hero) private var coverSize

    private var cover: some View {
        GalleryCover(url: gallery.coverURL, style: .hero)
    }

    private var textColumn: some View {
        VStack(alignment: .leading) {
            Button(action: showFullTitleAction) {
                Text(title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.leading)
                    .tint(.primary)
                    .lineLimit(titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(gallery.uploader ?? "", action: navigateUploaderAction)
                .lineLimit(uploaderLineLimit)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity, alignment: .top)

            bottomActionRow
        }
    }

    /// The cover is a fixed-width block, so beside it the title is drawn in whatever is left of the
    /// header — and at an accessibility size that remainder is a column a few glyphs wide, in which
    /// a `.title3` title spends a dozen lines saying what it could say in three. The two stop
    /// competing for the same width by not sharing a line: stacked, the title is offered the whole
    /// header and the cover keeps its designed size above it.
    ///
    /// The gap between them is 12: the cover is a large block of colour, so it needs more air than
    /// the default spacing SwiftUI gives the text rows inside the column beneath it.
    ///
    /// The stacked column takes no horizontal padding of its own. The 10pt the row applies is there
    /// to hold the column off the cover it sits beside; stacked there is nothing beside it, and any
    /// inset would indent the text relative to the cover above it and every section below it, all
    /// of which sit flush against the detail page's own margins. Below the accessibility sizes the
    /// designed row is rendered verbatim — same padding, same `minHeight`, which keeps the header
    /// at least as tall as the cover so the section below it never rides up beside it.
    @ViewBuilder var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                cover
                textColumn
            }
        } else {
            HStack(alignment: .top) {
                cover

                textColumn
                    .padding(.horizontal, 10)
                    .frame(minHeight: coverSize.height)
            }
        }
    }
}

// MARK: HeaderSection Accessibility
extension HeaderSection {
    var downloadButtonAccessibilityLabel: String {
        guard canDownload else { return String(localized: .accessibilityLogin) }
        guard !showsMetadataPreparation else {
            return String(localized: .accessibilityPreparing)
        }
        return downloadBadgeAccessibilityLabel
    }
    var downloadBadgeAccessibilityLabel: String {
        guard let badge = downloadBadge else {
            return String(localized: .accessibilityDownload)
        }
        let progress = badge.progress
        switch badge.status {
        case .queued:
            return String(localized: .accessibilityQueued)
        case .active:
            let downloading = String(localized: .accessibilityDownloading(
                completed: progress.completedPageCount, total: progress.displayPageCount
            ))
            return [downloading, String(localized: .accessibilityPauseAction)]
                .joined(separator: ". ")
        case .inactive:
            return String(localized: .accessibilityPaused(
                completed: progress.completedPageCount, total: progress.displayPageCount
            ))
        case .completed:
            return String(localized: .accessibilityDownloaded)
        case .updateAvailable:
            return String(localized: .accessibilityUpdate)
        case .error:
            if isPartialDownloadError {
                return String(localized: .accessibilityPartial(
                    available: progress.completedPageCount, total: progress.displayPageCount
                ))
            }
            return downloadNeedsRepair
                ? String(localized: .accessibilityRepair)
                : String(localized: .accessibilityRetry)
        }
    }
}

// MARK: HeaderSection Previews
// Section-scoped previews: the full DetailView preview pays the NavigationStack + ScrollView
// scaffolding cost on every canvas update, so iterate on a single section here instead.
@MainActor private func previewHeaderSection(
    downloadBadge: DownloadBadge? = nil,
    downloadNeedsRepair: Bool = false
) -> some View {
    HeaderSection(
        gallery: .preview,
        galleryDetail: .preview,
        downloadBadge: downloadBadge,
        downloadNeedsRepair: downloadNeedsRepair,
        downloadFolders: ["Default", "Favorites"],
        isPreparingDownload: false,
        canDownload: true,
        displayJapaneseTitle: false,
        showFullTitle: false,
        showFullTitleAction: {},
        downloadAction: {},
        downloadToFolderAction: { _ in },
        manageFoldersAction: {},
        createDefaultFolderAction: {},
        favorAction: { _ in },
        unfavorAction: {},
        navigateReadingAction: {},
        navigateUploaderAction: {}
    )
    .padding(.horizontal)
}

#Preview("Idle") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection()
    }
}

#Preview("Downloading") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(
            downloadBadge: .init(
                status: .active,
                progress: .init(completedPageCount: 47, pageCount: 114)
            )
        )
    }
}

#Preview("Accessibility size") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection()
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}

#Preview("Needs repair") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(
            downloadBadge: .init(
                status: .error,
                progress: .init(completedPageCount: 12, pageCount: 114)
            ),
            downloadNeedsRepair: true
        )
    }
}
