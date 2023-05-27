//
//  ArchivesView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/06.
//

import SwiftUI
import ComposableArchitecture

struct ArchivesView: View {
    private let store: StoreOf<ArchivesReducer>
    @ObservedObject private var viewStore: ViewStoreOf<ArchivesReducer>
    private let gid: String
    private let user: User
    private let galleryURL: URL
    private let archiveURL: URL

    init(
        store: StoreOf<ArchivesReducer>,
        gid: String, user: User, galleryURL: URL, archiveURL: URL
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        self.user = user
        self.galleryURL = galleryURL
        self.archiveURL = archiveURL
    }

    // MARK: ArchiveView
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    HathArchivesView(archives: viewStore.hathArchives, selection: viewStore.binding(\.$selectedArchive))
                    Spacer()
                    if let credits = Int(user.credits ?? ""), let galleryPoints = Int(user.galleryPoints ?? "") {
                        ArchiveFundsView(credits: credits, galleryPoints: galleryPoints)
                    }
                    DownloadButton(isDisabled: viewStore.selectedArchive == nil) {
                        viewStore.send(.fetchDownloadResponse(archiveURL))
                    }
                }
                .padding(.horizontal).opacity(viewStore.hathArchives.isEmpty ? 0 : 1)
                LoadingView().opacity(
                    viewStore.loadingState == .loading
                    && viewStore.hathArchives.isEmpty ? 1 : 0
                )
                let error = (/LoadingState.failed).extract(from: viewStore.loadingState)
                ErrorView(error: error ?? .unknown) {
                    viewStore.send(.fetchArchive(gid, galleryURL, archiveURL))
                }
                .opacity(error != nil && viewStore.hathArchives.isEmpty ? 1 : 0)
            }
            .progressHUD(
                config: viewStore.communicatingHUDConfig,
                unwrapping: viewStore.binding(\.$route),
                case: /ArchivesReducer.Route.communicatingHUD
            )
            .progressHUD(
                config: viewStore.messageHUDConfig,
                unwrapping: viewStore.binding(\.$route),
                case: /ArchivesReducer.Route.messageHUD
            )
            .animation(.default, value: viewStore.hathArchives)
            .animation(.default, value: user.galleryPoints)
            .animation(.default, value: user.credits)
            .onAppear {
                viewStore.send(.fetchArchive(gid, galleryURL, archiveURL))
            }
            .navigationTitle(L10n.Localizable.ArchivesView.Title.archives)
        }
    }
}

// MARK: HathArchivesView
private struct HathArchivesView: View {
    private let archives: [GalleryArchive.HathArchive]
    @Binding private var selection: GalleryArchive.HathArchive?

    init(archives: [GalleryArchive.HathArchive], selection: Binding<GalleryArchive.HathArchive?>) {
        self.archives = archives
        _selection = selection
    }

    private let gridItems = [
        GridItem(.adaptive(
            minimum: Defaults.FrameSize.archiveGridWidth,
            maximum: Defaults.FrameSize.archiveGridWidth
        ))
    ]

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
                        HathArchiveGrid(isSelected: selection == archive, archive: archive)
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
            Label("\(galleryPoints)", systemSymbol: .gCircleFill)
            Label("\(credits)", systemSymbol: .cCircleFill)
        }
        .font(.headline).lineLimit(1).padding()
    }
}

// MARK: HathArchiveGrid
private struct HathArchiveGrid: View {
    private let isSelected: Bool
    private let archive: GalleryArchive.HathArchive

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
    private var width: CGFloat {
        Defaults.FrameSize.archiveGridWidth
    }
    private var height: CGFloat {
        width / 1.5
    }

    init(isSelected: Bool, archive: GalleryArchive.HathArchive) {
        self.isSelected = isSelected
        self.archive = archive
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(archive.resolution.value).font(.title3.bold())
            VStack {
                Text(archive.fileSize).fontWeight(.medium).font(.caption)
                Text(archive.price).foregroundColor(fileSizeColor).font(.caption2)
            }
            .lineLimit(1)
        }
        .foregroundColor(foregroundColor)
        .frame(width: width, height: height)
        .contentShape(Rectangle()).overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: DownloadButton
private struct DownloadButton: View {
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
        DeviceUtil.isPadWidth
            ? .init(top: 0, leading: 0, bottom: 30, trailing: 0)
            : .init(top: 0, leading: 10, bottom: 30, trailing: 10)
    }

    var body: some View {
        HStack {
            Spacer()
            Text(L10n.Localizable.ArchivesView.Button.downloadToHathClient)
                .font(.headline).foregroundColor(textColor)
            Spacer()
        }
        .frame(height: 50).background(backgroundColor)
        .cornerRadius(30).padding(paddingInsets)
        .onTapGesture { if !isDisabled { action() }}
        .onLongPressGesture(
            minimumDuration: 0, maximumDistance: 50,
            pressing: { isPressing = $0 }, perform: {}
        )
    }
}

struct ArchivesView_Previews: PreviewProvider {
    static var previews: some View {
        ArchivesView(
            store: .init(
                initialState: .init(),
                reducer: ArchivesReducer()
            ),
            gid: .init(),
            user: .init(),
            galleryURL: .mock,
            archiveURL: .mock
        )
    }
}
