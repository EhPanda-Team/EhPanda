//
//  DetailView+HeaderSection.swift
//  EhPanda
//

import SwiftUI
import Kingfisher
import SFSafeSymbols

// MARK: HeaderSection
struct HeaderSection: View {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let user: User
    let downloadBadge: DownloadBadge?
    let downloadNeedsRepair: Bool
    let downloadFolders: [String]
    let isPreparingDownload: Bool
    let canDownload: Bool
    let displaysJapaneseTitle: Bool
    let showFullTitle: Bool
    let showFullTitleAction: () -> Void
    let downloadAction: () -> Void
    let downloadToFolderAction: (String) -> Void
    let manageFoldersAction: () -> Void
    let favorAction: (Int) -> Void
    let unfavorAction: () -> Void
    let navigateReadingAction: () -> Void
    let navigateUploaderAction: () -> Void

    private let actionIconButtonSize: CGFloat = 32
    private let actionIconFont: Font = .system(size: 16, weight: .semibold)

    private var title: String {
        let normalTitle = galleryDetail.title
        return displaysJapaneseTitle ? galleryDetail.jpnTitle ?? normalTitle : normalTitle
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
            text: gallery.category.value, color: gallery.color, font: .headline,
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
                                L10n.Localizable.DetailView.Menu.Button.manageFolders,
                                systemSymbol: .folderBadgeGearshape
                            )
                        }
                    }
                    Section {
                        if downloadFolders.isEmpty {
                            Text(L10n.Localizable.DetailView.Menu.Text.noFolders)
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
        ZStack {
            Button(action: unfavorAction) {
                Image(systemSymbol: .heartFill)
                    .font(actionIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            .opacity(galleryDetail.isFavorited ? 1 : 0)
            Menu {
                ForEach(0..<10) { index in
                    Button(user.getFavoriteCategory(index: index)) { favorAction(index) }
                }
            } label: {
                Image(systemSymbol: .heart)
                    .font(actionIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            .opacity(galleryDetail.isFavorited ? 0 : 1)
        }
        .foregroundStyle(.tint)
        .buttonStyle(.glass(.regular.interactive()))
        .buttonBorderShape(.circle)
        .disabled(!CookieUtil.didLogin)
    }
    private var readButton: some View {
        Button(action: navigateReadingAction) {
            Image(systemSymbol: .bookFill)
                .font(actionIconFont)
                .foregroundStyle(.white)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel(L10n.Localizable.DetailView.Button.read)
    }
    private func progressIndicator(
        progress: Double, isDeterminate: Bool, centerSymbol: SFSymbol
    ) -> some View {
        ZStack {
            if isDeterminate {
                Circle().stroke(downloadButtonTint.opacity(0.18), lineWidth: 2.5).padding(3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(downloadButtonTint, style: .init(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(downloadButtonTint)
                    .controlSize(.small)
            }
            Image(systemSymbol: centerSymbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(downloadButtonTint)
        }
        .frame(width: actionIconButtonSize, height: actionIconButtonSize)
    }
    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { downloadButton; favoriteButton; readButton }
                .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) { downloadButton; favoriteButton }
                readButton
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .trailing, spacing: 6) { downloadButton; favoriteButton; readButton }
                .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
    }
    private var bottomActionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { categoryLabel; Spacer(minLength: 8); actionButtons }

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
    private var resolvedCoverURL: URL? { gallery.coverURL }

    var body: some View {
        HStack {
            KFImage(resolvedCoverURL)
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
                Spacer()
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
        guard canDownload else { return L10n.Localizable.DetailView.Accessibility.DownloadButton.login }
        guard !showsMetadataPreparation else {
            return L10n.Localizable.DetailView.Accessibility.DownloadButton.preparing
        }
        return downloadBadgeAccessibilityLabel
    }
    var downloadBadgeAccessibilityLabel: String {
        guard let badge = downloadBadge else {
            return L10n.Localizable.DetailView.Accessibility.DownloadButton.download
        }
        let progress = badge.progress
        switch badge.status {
        case .queued:
            return L10n.Localizable.DetailView.Accessibility.DownloadButton.queued
        case .active:
            let downloading = L10n.Localizable.DetailView.Accessibility.DownloadButton.downloading(
                progress.completedPageCount, progress.displayPageCount
            )
            return [downloading, L10n.Localizable.DetailView.Accessibility.DownloadButton.pauseAction]
                .joined(separator: ". ")
        case .inactive:
            return L10n.Localizable.DetailView.Accessibility.DownloadButton.paused(
                progress.completedPageCount, progress.displayPageCount
            )
        case .completed:
            return L10n.Localizable.DetailView.Accessibility.DownloadButton.downloaded
        case .updateAvailable:
            return L10n.Localizable.DetailView.Accessibility.DownloadButton.update
        case .error:
            if isPartialDownloadError {
                return L10n.Localizable.DetailView.Accessibility.DownloadButton.partial(
                    progress.completedPageCount, progress.displayPageCount
                )
            }
            return downloadNeedsRepair
                ? L10n.Localizable.DetailView.Accessibility.DownloadButton.repair
                : L10n.Localizable.DetailView.Accessibility.DownloadButton.retry
        }
    }
}
