import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import SystemNotificationExt
import AppComponents

struct ArchivesView: View {
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
            ZStack {
                VStack {
                    HathArchivesView(archives: store.hathArchives, selection: $store.selectedArchive)

                    Spacer()

                    if let credits = Int(store.user.credits ?? ""),
                       let galleryPoints = Int(store.user.galleryPoints ?? "") {
                        ArchiveFundsView(credits: credits, galleryPoints: galleryPoints)
                    }

                    DownloadButton(isDisabled: store.selectedArchive == nil) {
                        store.send(.fetchDownloadResponse(archiveURL))
                    }
                }
                .padding(.horizontal)
                .opacity(store.hathArchives.isEmpty ? 0 : 1)

                LoadingView()
                    .opacity(
                        store.loadingState == .loading
                            && store.hathArchives.isEmpty ? 1 : 0
                    )

                let error = store.loadingState.failed
                ErrorView(error: error ?? .unknown) {
                    store.send(.fetchArchive(gid, galleryURL, archiveURL))
                }
                .opacity(error != nil && store.hathArchives.isEmpty ? 1 : 0)
            }
            .toast($store.scope(\.$toast, action: \.toast))
            .animation(.default, value: store.hathArchives)
            .animation(.default, value: store.user.galleryPoints)
            .animation(.default, value: store.user.credits)
            .onAppear {
                store.send(.fetchArchive(gid, galleryURL, archiveURL))
            }
            .navigationTitle(.archives)
        }
    }
}

// MARK: HathArchivesView
private struct HathArchivesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let archives: [GalleryArchive.HathArchive]
    @Binding private var selection: GalleryArchive.HathArchive?

    init(archives: [GalleryArchive.HathArchive], selection: Binding<GalleryArchive.HathArchive?>) {
        self.archives = archives
        _selection = selection
    }

    private var itemWidth: CGFloat { horizontalSizeClass == .regular ? 175 : 150 }
    private var gridItems: [GridItem] {
        [GridItem(.adaptive(minimum: itemWidth, maximum: itemWidth))]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridItems, spacing: 10) {
                ForEach(archives) { archive in
                    Button {
                        if archive.isValid {
                            selection = archive
                            HapticsUtil.generateFeedback(style: .soft)
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
}

// MARK: ArchiveFundsView
private struct ArchiveFundsView: View {
    private let credits: Int
    private let galleryPoints: Int

    init(credits: Int, galleryPoints: Int) {
        self.credits = credits
        self.galleryPoints = galleryPoints
    }

    var body: some View {
        HStack(spacing: 20) {
            Label {
                Text(galleryPoints, format: .number)
            } icon: {
                Image(systemSymbol: .gCircleFill)
            }
            Label {
                Text(credits, format: .number)
            } icon: {
                Image(systemSymbol: .cCircleFill)
            }
        }
        .font(.headline.monospacedDigit()).lineLimit(1).padding()
    }
}

// MARK: HathArchiveGrid
private struct HathArchiveGrid: View {
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
        VStack(spacing: 10) {
            Text(archive.resolution.value)
                .font(.title3.bold())

            VStack {
                Text(archive.fileSize)
                    .fontWeight(.medium)
                    .font(.caption)

                Text(archive.price)
                    .foregroundColor(fileSizeColor)
                    .font(.caption2)
            }
            .lineLimit(1)
        }
        .foregroundColor(foregroundColor)
        .frame(width: width, height: height)
        .contentShape(.rect)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
        .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 10))
    }
}

// MARK: DownloadButton
private struct DownloadButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isPressing = false

    private var isDisabled: Bool
    private var action: () -> Void

    init(isDisabled: Bool, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    private var textColor: Color {
        isDisabled ? .white.opacity(0.5) : isPressing ? .white.opacity(0.5) : .white
    }
    private var backgroundColor: Color {
        isDisabled ? .accentColor.opacity(0.5) : isPressing ? .accentColor.opacity(0.5) : .accentColor
    }
    private var paddingInsets: EdgeInsets {
        horizontalSizeClass == .regular
            ? .init(top: 0, leading: 0, bottom: 30, trailing: 0)
            : .init(top: 0, leading: 10, bottom: 30, trailing: 10)
    }

    var body: some View {
        Text(.downloadToHathClient)
            .font(.headline)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .animation(.default, value: backgroundColor)
            .clipShape(.rect(cornerRadius: 30))
            .glassEffect(.regular.interactive())
            .padding(paddingInsets)
            .onTapGesture(perform: { if !isDisabled { action() }})
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: 50,
                pressing: { isPressing = $0 },
                perform: {}
            )
    }
}

struct ArchivesView_Previews: PreviewProvider {
    static var previews: some View {
        ArchivesView(
            store: .init(initialState: .init(), reducer: ArchivesReducer.init),
            gid: .init(),
            galleryURL: .mock,
            archiveURL: .mock
        )
    }
}
