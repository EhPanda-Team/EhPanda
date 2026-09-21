import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import Dependencies
import HapticsClient
import Resources
import SwiftUI
import SystemNotification

struct ArchivesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable private var store: StoreOf<ArchivesReducer>
    private let gid: String
    private let galleryURL: URL
    private let archiveURL: URL

    init(
        store: StoreOf<ArchivesReducer>,
        gid: String, galleryURL: URL, archiveURL: URL
    ) {
        self.store = store
        self.gid = gid
        self.galleryURL = galleryURL
        self.archiveURL = archiveURL
    }

    // MARK: ArchiveView
    var body: some View {
        NavigationStack {
            sheetContent
                .padding(.horizontal)
                .animation(.default) {
                    $0.visible(!store.hathArchives.isEmpty)
                }
                .overlay {
                    LoadingView()
                        .animation(.default) {
                            $0.visible(store.loadingState == .loading && store.hathArchives.isEmpty)
                        }
                }
                .overlay {
                    let error = store.loadingState.failed
                    ErrorView(error: error ?? .unknown) {
                        store.send(.fetchArchive(gid: gid, galleryURL: galleryURL, archiveURL: archiveURL))
                    }
                    .animation(.default) {
                        $0.visible(error != nil && store.hathArchives.isEmpty)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .toast($store.scope(\.$toast, action: \.toast))
                .navigationTitle(.archives)
        }
    }

    /// The sheet has two arrangements, and the choice between them is an explicit size read rather
    /// than a `ViewThatFits(in: .vertical)`.
    ///
    /// A vertical fitting test would answer the wrong question here. It compares the *ideal* height
    /// of the pinned arrangement — the grid's full content height, since that is what a `ScrollView`
    /// reports — against the height on offer, and the pinned arrangement is designed to be taller
    /// than that: its grid scrolls, which is the whole point of the inner `ScrollView`. The test
    /// therefore flips to the fallback the moment the archives outgrow the sheet, which already
    /// happens at the default size in landscape, where the pinned layout is exactly the intended
    /// rendering. Default-size parity outranks the elegance of a measurement, so the gate is the
    /// size itself.
    ///
    /// The threshold is the accessibility boundary, the same one the grid and the cards already
    /// read: that is where a card stops sharing its row and grows to the height its own text needs,
    /// so it is also where the funds row and the download banner stop leaving the grid a usable
    /// share of the sheet.
    @ContentBuilder private var sheetContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            scrollingColumn
        } else {
            pinnedColumn
        }
    }

    /// The designed arrangement: the grid scrolls inside the height left over, and the funds row
    /// and the download banner stay pinned below it, always on screen. Used verbatim at every size
    /// below the accessibility threshold.
    private var pinnedColumn: some View {
        VStack {
            ScrollView(showsIndicators: false) {
                archiveGrid
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .scrollEdgeEffectStyle(.soft, for: .top)

            funds
            downloadButton
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    /// Above the threshold the pinned footer is given up: it grows with the text until it owns the
    /// sheet, leaving the archives — the thing the sheet exists to choose between — as a sliver or
    /// nothing at all. Everything scrolls together instead, in reading order, so the grid keeps a
    /// full sheet to itself and the funds and the banner are one flick away.
    ///
    /// The scroll indicator is hidden, as it is on the grid's own scroll view and on every other
    /// scrolling surface of the app; the banner below the fold is one flick away, like everywhere
    /// else, and a lone visible indicator would read as a different kind of screen.
    ///
    /// 20 points between the three blocks: each already carries its own padding (16 around the
    /// funds row, 30 below the banner), so 20 lands a 36-point gap on either side of the funds row.
    /// That is enough, at these text sizes, to keep the balances from reading as one more card at
    /// the end of the grid and the banner from reading as the tail of the balances. The sheet's
    /// horizontal padding stays outside both arrangements, so nothing hugs the sheet's edge here
    /// either.
    private var scrollingColumn: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                archiveGrid
                funds
                downloadButton
            }
        }
    }

    /// The grid of archive cards, without a scroll container of its own: the two arrangements
    /// scroll at different levels, and nesting one inside the other would leave the grid scrolling
    /// against a container that is itself scrolling.
    private var archiveGrid: some View {
        HathArchivesView(archives: store.hathArchives, selection: $store.selectedArchive)
    }

    @ContentBuilder private var funds: some View {
        let placeholderValue = 100000
        let credits = store.user.credits.flatMap(Int.init)
        let galleryPoints = store.user.galleryPoints.flatMap(Int.init)

        ArchiveFundsView(credits: credits ?? placeholderValue, galleryPoints: galleryPoints ?? placeholderValue)
            .animation(.default) {
                $0.redacted(reason: credits != nil && galleryPoints != nil ? .init() : .placeholder)
            }
            .accessibilityHidden(credits == nil || galleryPoints == nil)
    }

    private var downloadButton: some View {
        DownloadButton(isDisabled: store.selectedArchive == nil) {
            store.send(.fetchDownloadResponse(archiveURL))
        }
    }
}

// MARK: HathArchivesView
private struct HathArchivesView: View {
    @Dependency(\.hapticsClient) private var hapticsClient
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let archives: [GalleryArchive.HathArchive]
    @Binding private var selection: GalleryArchive.HathArchive?

    init(archives: [GalleryArchive.HathArchive], selection: Binding<GalleryArchive.HathArchive?>) {
        self.archives = archives
        _selection = selection
    }

    private var itemWidth: CGFloat {
        DetailLayout.archiveWidth(regular: horizontalSizeClass == .regular)
    }

    /// A 150-point column cannot hold a resolution name, a file size and a price at an
    /// accessibility size, and this grid is the sheet's primary control: the two values the user
    /// is choosing between are exactly the two the narrow card drops. One column per row hands
    /// every card the sheet's whole width, which is the only width there is.
    private var gridItems: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: itemWidth, maximum: itemWidth))]
    }

    /// The grid alone. Its caller owns the scrolling, because which container scrolls depends on
    /// the arrangement the sheet is in.
    var body: some View {
        LazyVGrid(columns: gridItems, spacing: 10) {
            ForEach(archives) { archive in
                Button {
                    if archive.isValid {
                        selection = archive
                        hapticsClient.generateFeedback(.soft)
                    }
                } label: {
                    HathArchiveGrid(
                        isSelected: selection == archive,
                        archive: archive,
                        width: itemWidth
                    )
                    .tint(.primary).multilineTextAlignment(.center)
                }
            }
        }
        .padding(.top, 40)
    }
}

// MARK: ArchiveFundsView
private struct ArchiveFundsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let credits: Int
    private let galleryPoints: Int

    init(credits: Int, galleryPoints: Int) {
        self.credits = credits
        self.galleryPoints = galleryPoints
    }

    /// The two balances are a stat pair: they share a line for as long as both fit it whole, and
    /// take a line each once they do not. The pair is deliberately *not* space-between — the row
    /// is centred as a block today and stays so — and both balances are numbers, whose ideal
    /// widths are honest, so `ViewThatFits` can arbitrate this level.
    ///
    /// The coin glyphs are decorative to assistive technology: they would be announced by their
    /// symbol names beside each number, so they are hidden and the balances are read as text.
    var body: some View {
        AdaptiveStack(hSpacing: 20) {
            Label {
                Text(galleryPoints, format: .number)
                    .contentTransition(.numericText(value: Double(galleryPoints)))
                    .animation(.default, value: galleryPoints)
            } icon: {
                Image(systemSymbol: .gCircleFill)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(.accessibilityGalleryPointsBalance(balance: galleryPoints))
            Label {
                Text(credits, format: .number)
                    .contentTransition(.numericText(value: Double(credits)))
                    .animation(.default, value: credits)
            } icon: {
                Image(systemSymbol: .cCircleFill)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(.accessibilityCreditsBalance(balance: credits))
        }
        .font(.headline.monospacedDigit()).lineLimit(balanceLineLimit).padding()
    }

    /// A balance can run to nine digits, so at the largest sizes a line of its own is still not
    /// enough for it: above the default size the cap comes off so the number wraps rather than
    /// ending in an ellipsis two digits in. Wherever one line suffices this changes nothing, the
    /// designed rendering at and below the default size included.
    private var balanceLineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }
}

// MARK: HathArchiveGrid
private struct HathArchiveGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let isSelected: Bool
    private let archive: GalleryArchive.HathArchive
    private let width: CGFloat

    private var disabledColor: Color {
        .gray.opacity(0.5)
    }
    private var fileSizeColor: Color {
        !archive.isValid ? disabledColor : .gray
    }
    private var borderColor: Color {
        !archive.isValid ? disabledColor : isSelected ? .accentColor : .gray
    }
    private var foregroundColor: Color? {
        !archive.isValid ? disabledColor : nil
    }
    private var height: CGFloat {
        width / 1.5
    }

    init(isSelected: Bool, archive: GalleryArchive.HathArchive, width: CGFloat) {
        self.isSelected = isSelected
        self.archive = archive
        self.width = width
    }

    var body: some View {
        sizedCard
            .contentShape(.rect)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
            .glassEffect(.clear, in: .rect(cornerRadius: 10))
    }

    /// A card frozen at 150 × 100 does not clip the three lines that outgrow it — it draws them
    /// outside its own border, over the neighbouring card and over the funds row below. Above the
    /// accessibility threshold the card fills its (now single) column and takes the height its
    /// contents ask for, so the border always encloses what it is drawn around. Below it the
    /// designed card is used verbatim.
    @ContentBuilder private var sizedCard: some View {
        if dynamicTypeSize.isAccessibilitySize {
            tintedCard
                .padding(10)
                .frame(maxWidth: .infinity)
        } else {
            tintedCard
                .frame(width: width, height: height)
        }
    }

    // `foregroundColor` is optional: nil means inherit the ambient tint, so
    // apply `foregroundStyle` only when a concrete color is supplied.
    @ContentBuilder private var tintedCard: some View {
        let card = VStack(spacing: 10) {
            Text(archive.resolution.value)
                .font(.title3.bold())

            VStack {
                Text(archive.fileSize)
                    .fontWeight(.medium)
                    .font(.caption)

                Text(archive.price)
                    .foregroundStyle(fileSizeColor)
                    .font(.caption2)
            }
            .lineLimit(statLineLimit)
        }
        if let foregroundColor {
            card.foregroundStyle(foregroundColor)
        } else {
            card
        }
    }

    /// The size and the price are the two values the user is choosing between, so above the
    /// default size they lose their cap: a value that outgrows its line wraps instead of being
    /// abbreviated into another archive's twin. Each already owns a full-width line of the card,
    /// so a single line is what they keep wherever one is enough — the designed rendering at and
    /// below the default size included.
    private var statLineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }
}

// MARK: DownloadButton
/// A real `Button`, so VoiceOver announces the banner as one with its visible title and Voice
/// Control lists it by that title; the tap-and-long-press pair it replaced had neither a role nor
/// a name. `.disabled` carries the no-selection state as the button's own state.
private struct DownloadButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // 50pt at default (.large); scales with Dynamic Type relative to the banner's text style (.headline).
    @ScaledMetric(relativeTo: .headline) private var bannerHeight: CGFloat = 50

    private var isDisabled: Bool
    private var action: () -> Void

    init(isDisabled: Bool, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    private var paddingInsets: EdgeInsets {
        horizontalSizeClass == .regular
            ? .init(top: 0, leading: 0, bottom: 30, trailing: 0)
            : .init(top: 0, leading: 10, bottom: 30, trailing: 10)
    }

    var body: some View {
        Button(action: action) {
            Text(.downloadToHathClient)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: bannerHeight)
        }
        .buttonStyle(DownloadBannerStyle())
        .padding(paddingInsets)
        .disabled(isDisabled)
    }
}

/// The banner's designed rendering, drawn from the button's own state instead of a tracked
/// long-press: white on the accent colour, both at half opacity while pressed or disabled, with
/// the colour change animated. `.plain` would have dropped the pressed dimming, so the style is
/// what keeps the appearance identical to the gesture-driven original.
private struct DownloadBannerStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let isDimmed = !isEnabled || configuration.isPressed
        configuration.label
            .foregroundStyle(isDimmed ? .white.opacity(0.5) : .white)
            .animation(.default) {
                $0.background(isDimmed ? Color.accentColor.opacity(0.5) : Color.accentColor)
            }
            .clipShape(.rect(cornerRadius: 30))
            .glassEffect(.regular.interactive())
    }
}

@MainActor private func previewArchivesView() -> some View {
    ArchivesView(
        store: .init(
            initialState: .init(hathArchives: .preview),
            reducer: ArchivesReducer.init
        ),
        gid: .init(),
        galleryURL: .mock,
        archiveURL: .mock
    )
}

#Preview("Initial") {
    previewArchivesView()
}

// The 380-point frames stand in for the sheet's height on an iPhone held in landscape, which is
// where the pinned footer used to take the whole sheet and leave the archives a sliver.
#Preview("Accessibility 3, landscape height") {
    previewArchivesView()
        .frame(height: 380)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5, landscape height") {
    previewArchivesView()
        .frame(height: 380)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Accessibility 3, portrait height") {
    previewArchivesView()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility 5, portrait height") {
    previewArchivesView()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private extension [GalleryArchive.HathArchive] {
    static let preview: Self = [
        .init(resolution: .x780, fileSize: "12 MB", gpPrice: "20"),
        .init(resolution: .x980, fileSize: "18 MB", gpPrice: "30"),
        .init(resolution: .x1280, fileSize: "24 MB", gpPrice: "40"),
        .init(resolution: .x1600, fileSize: "32 MB", gpPrice: "50"),
        .init(resolution: .x2400, fileSize: "48 MB", gpPrice: "Free"),
        .init(resolution: .original, fileSize: "N/A", gpPrice: "N/A")
    ]
}
