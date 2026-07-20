import SwiftUI
import Sharing
import AppModels
import Resources
import Kingfisher
import SFSafeSymbols
import ComposableArchitecture
import AppTools
import AppComponents
import CookieClient
import SFSafeSymbolsExt

// MARK: HeaderSection
struct HeaderSection: View {
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

    private let actionIconButtonSize: CGFloat = 32
    // 16pt at default (.large); scales with Dynamic Type relative to the nearest text style (.callout, 16pt).
    @ScaledMetric(relativeTo: .callout) private var actionIconFontSize: CGFloat = 16
    private var actionIconFont: Font { .system(size: actionIconFontSize, weight: .semibold) }
    // 10pt at default (.large); scales with Dynamic Type relative to the nearest text style (.caption2, 11pt).
    @ScaledMetric(relativeTo: .caption2) private var progressCenterSymbolSize: CGFloat = 10

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
    private var categoryLabel: some View {
        CategoryLabel(
            text: gallery.category.value, color: gallery.color(host: setting.galleryHost), font: .headline,
            insets: .init(top: 2, leading: 4, bottom: 2, trailing: 4), cornerRadius: 3
        )
        .lineLimit(1)
        .minimumScaleFactor(0.72)
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
            Image(systemSymbol: .heart)
                .font(actionIconFont)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
        .animation(.default) {
            $0.opacity(galleryDetail.isFavorited ? 0 : 1)
        }
        .overlay {
            Button(action: unfavorAction) {
                Label(.favorited, systemSymbol: .heartFill)
                    .labelStyle(.iconOnly)
                    .font(actionIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            .animation(.default) {
                $0.opacity(galleryDetail.isFavorited ? 1 : 0)
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
            .stroke(downloadButtonTint.opacity(0.18), lineWidth: 2.5)
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(downloadButtonTint, style: .init(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.default, value: progress)
            }
            .padding(3)
            .animation(.default) {
                $0.opacity(isDeterminate ? 1 : 0)
            }
            .overlay {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(downloadButtonTint)
                    .controlSize(.small)
                    .animation(.default) {
                        $0.opacity(isDeterminate ? 0 : 1)
                    }
            }
            .overlay {
                Image(systemSymbol: centerSymbol)
                    .font(.system(size: progressCenterSymbolSize, weight: .semibold))
                    .foregroundStyle(downloadButtonTint)
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

    var body: some View {
        HStack {
            KFImage(gallery.coverURL)
                .placeholder({ Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) })
                .defaultModifier()
                .scaledToFit()
                .frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)

            VStack(alignment: .leading) {
                Button(action: showFullTitleAction) {
                    Text(title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.leading)
                        .tint(.primary)
                        .lineLimit(showFullTitle ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(gallery.uploader ?? "", action: navigateUploaderAction)
                    .lineLimit(1).font(.callout).foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .top)

                bottomActionRow
            }
            .padding(.horizontal, 10)
            .frame(minHeight: Defaults.ImageSize.headerH)
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
