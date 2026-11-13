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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    /// The page the reader resumes at; 0 for a gallery that was never read.
    let readingProgress: Int
    let navigateReadingAction: () -> Void
    let readButtonFocus: AccessibilityFocusState<Bool>.Binding
    let navigateUploaderAction: () -> Void

    // 32pt at default (.large); scales on the same metric as the symbol it holds, so the glass
    // circle grows exactly as fast as the glyph inside it. A fixed size here let the symbol outgrow
    // its own background and spill outside the circle at accessibility sizes.
    @ScaledMetric(relativeTo: .callout) private var actionIconButtonSize: CGFloat = 32
    // 16pt at default (.large); scales with Dynamic Type relative to the nearest text style (.callout, 16pt).
    @ScaledMetric(relativeTo: .callout) private var actionIconFontSize: CGFloat = 16
    private var actionIconFont: Font { .system(size: actionIconFontSize, weight: .semibold) }
    // The download and favourite glyphs are drawn larger than `.callout` so the three buttons' glyphs read as one
    // size (owner decision, 2026-11-21): the Read button's book is a solid shape on a solid button, and the outline
    // glyphs beside it look smaller at the same point size. Measured ink at `.callout`: cloud 20 x 18 pt, heart
    // 16 x 14.75, book 18.5 x 14.5. The heart's factor applies to `heart` and `heart.fill` alike, so it keeps its
    // size when tapped. Both multiply `actionIconFontSize`, so they scale with Dynamic Type exactly as the book
    // does; every glass circle keeps `actionIconButtonSize`.
    private static let downloadIconScale: CGFloat = 1.1
    private static let heartIconScale: CGFloat = 1.15
    private var downloadIconFont: Font {
        .system(size: actionIconFontSize * Self.downloadIconScale, weight: .semibold)
    }
    private var heartIconFont: Font {
        .system(size: actionIconFontSize * Self.heartIconScale, weight: .semibold)
    }
    // 2.5pt thick and 4pt in from the button's edge at default (.large). The ring is drawn over the whole glass
    // button (48pt at default: the 32pt label and the glass style's padding), so it traces the button's own circle
    // instead of sitting as a smaller disc inside the label (owner decision, 2026-11-21). Both scale on the
    // button's own metric, so the ring keeps its place and weight as the button grows.
    @ScaledMetric(relativeTo: .callout) private var progressRingLineWidth: CGFloat = 2.5
    @ScaledMetric(relativeTo: .callout) private var progressRingInset: CGFloat = 4

    private var title: String {
        var titledGallery = gallery
        titledGallery.title = galleryDetail.title
        titledGallery.jpnTitle = galleryDetail.jpnTitle
        return titledGallery.displayTitle(prefersJapanese: displayJapaneseTitle)
    }
    private var showsMetadataPreparation: Bool { isPreparingDownload && downloadBadge == nil }
    /// Whether the download glyph turns while the gallery's metadata is being prepared. Spinning is
    /// motion Apple's Reduced Motion criteria name explicitly, so under Reduce Motion the glyph is
    /// not slowed but held upright, and ``downloadIconLabel`` pulses it instead (`.symbolEffect(.pulse)`
    /// is an opacity-only effect): the "work in progress" affordance survives without rotation.
    private var spinsDownloadIcon: Bool { showsMetadataPreparation && !reduceMotion }
    /// One full turn every 0.9 s for as long as the preparation lasts; back to `.default` once it ends,
    /// so the glyph settles like any other state change. Under Reduce Motion the spin never starts
    /// (see ``spinsDownloadIcon``), and the repeating animation must not either — a `repeatForever`
    /// attached to a view that no longer rotates would still re-run every other change beneath it.
    private var downloadPreparationAnimation: Animation {
        guard spinsDownloadIcon else { return .default }
        return .linear(duration: 0.9).repeatForever(autoreverses: false)
    }
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
    /// The header measures the category and controls at their intrinsic sizes, keeping the category
    /// beside the controls while a complete arrangement fits. At narrower widths the category gets
    /// its own row and follows its normal wrapping policy; the action controls retain their size.
    private var categoryLabel: some View {
        CategoryLabel(
            text: gallery.category.value, color: gallery.color(host: setting.galleryHost), textStyle: .headline,
            insets: .init(top: 2, leading: 4, bottom: 2, trailing: 4), cornerRadius: 3
        )
    }
    private var downloadButton: some View {
        Group {
            // Queued, downloading and paused are one button, so when a download starts the dashed track cross-fades
            // and the arc grows instead of one button replacing another.
            if let ring = downloadRing {
                Button(action: downloadAction) {
                    // Decorative: the button announces the status and the action through
                    // `downloadButtonAccessibilityLabel`, so the glyph would only be read twice.
                    Image(systemSymbol: activeDownloadIconSymbol)
                        .font(actionIconFont)
                        .foregroundStyle(downloadButtonTint)
                        .frame(width: actionIconButtonSize, height: actionIconButtonSize)
                        .contentShape(.circle)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
                .overlay {
                    downloadProgressRing(fraction: ring.fraction, isWaiting: ring.isWaiting)
                }
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
                                    .RLocalizable.createDefaultFolder,
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
                .animation(downloadPreparationAnimation, value: showsMetadataPreparation)
            } else {
                Button(action: downloadAction) {
                    downloadIconLabel
                }
                .buttonStyle(.glass(.regular.interactive()))
                .buttonBorderShape(.circle)
            }
        }
        .disabled(isDownloadActionDisabled)
        .accessibilityLabel(downloadButtonAccessibilityLabel)
    }
    private var downloadIconLabel: some View {
        Image(systemSymbol: downloadIconSymbol)
            // Reduce Motion's stand-in for the spin below: same state, no rotation (D-29).
            .symbolEffect(.pulse, isActive: showsMetadataPreparation && reduceMotion)
            .font(downloadIconFont)
            .foregroundStyle(canDownload ? downloadButtonTint : .secondary)
            .rotationEffect(.degrees(spinsDownloadIcon ? 360 : 0))
            .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            .contentShape(.circle)
    }
    /// The colour of the slot the gallery is favorited in: the detail page's own reading, else the one the list
    /// row it was opened from carried; the accent colour when neither says which slot.
    private var favoriteColor: Color {
        Defaults.FavoriteColor.color(at: galleryDetail.favoriteTagIndex ?? gallery.favoriteTagIndex)
            ?? Color.accentColor
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
                .font(heartIconFont)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
        .animation(.default) {
            $0.visible(!galleryDetail.isFavorited)
        }
        .overlay {
            Button(action: unfavorAction) {
                Label(.favorited, systemSymbol: .heartFill)
                    .labelStyle(.iconOnly)
                    .font(heartIconFont)
                    .frame(width: actionIconButtonSize, height: actionIconButtonSize)
            }
            // The heart takes the colour of the favorites slot the gallery is in.
            .tint(favoriteColor)
            .accessibilityLabel(.accessibilityRemoveFromFavorites)
            .accessibilityAddTraits(.isSelected)
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
            readButtonLabel
                .foregroundStyle(.white)
        }
        .buttonStyle(.glassProminent)
        // A gallery with a saved page stretches the circle into a capsule to hold the page's label.
        .buttonBorderShape(readingProgress > 0 ? .capsule : .circle)
        // The control stays "Read" for VoiceOver and Voice Control; the saved page is its value.
        .accessibilityLabel(.read)
        .accessibilityValue(readButtonAccessibilityValue)
        .accessibilityFocused(readButtonFocus)
    }
    /// The book glyph, or, once the gallery has a saved page, that page's label (for example "P12"). The label
    /// scales with Dynamic Type like the other controls' glyphs, and the capsule grows to hold it.
    @ContentBuilder private var readButtonLabel: some View {
        if readingProgress > 0 {
            Text(.readProgress(page: readingProgress))
                .font(actionIconFont)
                .monospacedDigit()
                .lineLimit(1)
                // The capsule brings its own horizontal padding, wider than the circle's, so the label's minimum
                // width is what leaves a one-digit page as wide as the circle it replaces.
                .frame(minWidth: actionIconButtonSize * 0.65, minHeight: actionIconButtonSize)
        } else {
            Label(.read, systemSymbol: .bookFill)
                .labelStyle(.iconOnly)
                .font(actionIconFont)
                .frame(width: actionIconButtonSize, height: actionIconButtonSize)
        }
    }
    private var readButtonAccessibilityValue: String {
        readingProgress > 0 ? String(localized: .accessibilityPreviewPage(page: readingProgress)) : String()
    }
    /// The download ring, drawn over the whole glass button rather than inside its label: a track in the tint at
    /// 18 % and an arc in the tint from 12 o'clock clockwise for the pages saved, so an arc of 0 draws nothing.
    /// While the download waits its turn the track is twelve dashes (``DownloadRingDashes``); when it starts they
    /// cross-fade into the solid track over 0.3s while the arc grows from where it is, one view throughout. Under
    /// Reduce Motion the track switches at once (owner decision, 2026-11-21), a deliberate exception to D-29, which
    /// leaves an opacity change ungated. It neither takes touches nor speaks: the button under it does both.
    private func downloadProgressRing(fraction: Double, isWaiting: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(downloadButtonTint.opacity(0.18), lineWidth: progressRingLineWidth)
                .visible(!isWaiting)
            DownloadRingDashes()
                .stroke(
                    downloadButtonTint.opacity(0.18),
                    style: .init(lineWidth: progressRingLineWidth, lineCap: .butt)
                )
                .visible(isWaiting)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isWaiting)
        .overlay {
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(downloadButtonTint, style: .init(lineWidth: progressRingLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.default, value: fraction)
        }
        // The stroke is centred on its path, so the path sits half a line width past the inset.
        .padding(progressRingInset + progressRingLineWidth / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    private var bottomActionRow: some View {
        HeaderActionsLayout {
            categoryLabel
            downloadButton
            favoriteButton
            readButton
        }
    }
    /// The download ring of a queued, downloading or paused gallery. The arc is the pages already saved, the queued
    /// state included, so a resumed download keeps its arc while it waits its turn; `isWaiting` is the queued state,
    /// whose track is dashed. `nil` for every other state, which shows a glyph.
    private var downloadRing: (fraction: Double, isWaiting: Bool)? {
        guard let badge = downloadBadge,
              [.queued, .active, .inactive].contains(badge.status)
        else { return nil }
        return (fraction: badge.progress.fraction, isWaiting: badge.status == .queued)
    }
    /// The glyph inside the download ring is the action a tap performs: pause while the download is queued or
    /// running, play to resume a paused one.
    private var activeDownloadIconSymbol: SFSymbol {
        downloadBadge?.status == .inactive ? .playFill : .pauseFill
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
        default: return .icloudAndArrowDown
        }
    }

    @GalleryCoverMetrics(.hero) private var coverSize

    /// The cover is decorative here: the title, uploader and category beside it say everything it
    /// shows, and the audit (16-24) otherwise reports the unlabeled image as an element with no
    /// description.
    private var cover: some View {
        GalleryCover(url: gallery.coverURL, style: .hero)
            .accessibilityHidden(true)
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
                .accessibilityHidden(gallery.uploader?.isEmpty != false)
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
    @ContentBuilder var body: some View {
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
            let queued = progress.completedPageCount == 0
                ? String(localized: .accessibilityQueued)
                : String(localized: .accessibilityQueuedProgress(
                    completed: progress.completedPageCount, total: progress.displayPageCount
                ))
            return [queued, String(localized: .accessibilityPauseAction)]
                .joined(separator: ". ")
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

// MARK: DownloadRingDashes
/// The download ring's track while the download waits its turn: twelve dashes on the circle inscribed in the rect,
/// each covering 60 % of its 30-degree segment, the first starting at 12 o'clock and running clockwise (the
/// design's dash pattern, 5 on and 3.333 off over a path length of 100). Stroked with butt caps, so the gaps stay
/// open at every size. A shape rather than a dashed `StrokeStyle`: a dash pattern is given in points, so it would
/// need the ring's measured circumference to land twelve whole dashes, where the shape divides whatever circle it
/// is given.
private struct DownloadRingDashes: Shape {
    private static let dashCount = 12
    private static let dashShare = 0.6

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let segment = 360 / Double(Self.dashCount)
        var path = Path()
        for index in 0..<Self.dashCount {
            // Each dash is its own subpath, so no line joins one dash to the next; a positive delta runs clockwise
            // in SwiftUI's y-down space.
            var dash = Path()
            dash.addRelativeArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90 + segment * Double(index)),
                delta: .degrees(segment * Self.dashShare)
            )
            path.addPath(dash)
        }
        return path
    }
}

// MARK: HeaderSection Previews
// Section-scoped previews: the full DetailView preview pays the NavigationStack + ScrollView
// scaffolding cost on every canvas update, so iterate on a single section here instead.
@MainActor private func previewHeaderSection(
    readButtonFocus: AccessibilityFocusState<Bool>.Binding,
    downloadBadge: DownloadBadge? = nil,
    downloadNeedsRepair: Bool = false,
    readingProgress: Int = 0
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
        readingProgress: readingProgress,
        navigateReadingAction: {},
        readButtonFocus: readButtonFocus,
        navigateUploaderAction: {}
    )
    .padding(.horizontal)
}

#Preview("Idle") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(readButtonFocus: $readButtonFocused)
    }
}

#Preview("Downloading") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(
            readButtonFocus: $readButtonFocused,
            downloadBadge: .init(
                status: .active,
                progress: .init(completedPageCount: 47, pageCount: 114)
            )
        )
    }
}

#Preview("Queued") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(
            readButtonFocus: $readButtonFocused,
            downloadBadge: .init(
                status: .queued,
                progress: .init(completedPageCount: 0, pageCount: 114)
            )
        )
    }
}

#Preview("Queued, resumed") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(
            readButtonFocus: $readButtonFocused,
            downloadBadge: .init(
                status: .queued,
                progress: .init(completedPageCount: 47, pageCount: 114)
            )
        )
    }
}

#Preview("Accessibility size") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(readButtonFocus: $readButtonFocused)
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}

#Preview("Needs repair") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(
            readButtonFocus: $readButtonFocused,
            downloadBadge: .init(
                status: .error,
                progress: .init(completedPageCount: 12, pageCount: 114)
            ),
            downloadNeedsRepair: true
        )
    }
}

#Preview("Resumes at page 12") {
    @Previewable @AccessibilityFocusState var readButtonFocused: Bool
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        previewHeaderSection(readButtonFocus: $readButtonFocused, readingProgress: 12)
    }
}
