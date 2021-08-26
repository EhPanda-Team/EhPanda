//
//  ArchiveView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/06.
//

import SwiftUI
import SwiftyBeaver
import TTProgressHUD

struct ArchiveView: View, StoreAccessor, PersistenceAccessor {
    @EnvironmentObject var store: Store
    @State private var selection: ArchiveRes?

    @State private var archive: GalleryArchive?
    @State private var response: String?
    @State private var loadingFlag = false
    @State private var loadError: AppError?
    @State private var sendingFlag = false
    @State private var sendFailedFlag = false

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()
    private var loadingHUDConfig = TTProgressHUDConfig(
        type: .loading, title: "Communicating...".localized
    )
    private let gridItems = [
        GridItem(.adaptive(
            minimum: Defaults.FrameSize.archiveGridWidth,
            maximum: Defaults.FrameSize.archiveGridWidth
        ))
    ]

    let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: ArchiveView
    var body: some View {
        NavigationView {
            Group {
                if !hathArchives.isEmpty {
                    ZStack {
                        VStack {
                            ScrollView(showsIndicators: false) {
                                LazyVGrid(columns: gridItems, spacing: 10) {
                                    ForEach(hathArchives) { hathArchive in
                                        ArchiveGrid(
                                            isSelected: selection
                                                == hathArchive.resolution,
                                            archive: hathArchive
                                        )
                                        .onTapGesture(perform: {
                                            onArchiveGridTap(item: hathArchive)
                                        })
                                    }
                                }
                                .padding(.top, 40)
                            }

                            Spacer()

                            if let galleryPoints = currentGP?.withComma,
                               let credits = currentCredits?.withComma
                            {
                                HStack(spacing: 20) {
                                    Label(galleryPoints, systemImage: "g.circle.fill")
                                    Label(credits, systemImage: "c.circle.fill")
                                }
                                .font(.headline)
                                .lineLimit(1)
                                .padding()
                            }
                            DownloadButton(
                                isDisabled: selection == nil,
                                action: onDownloadButtonTap
                            )
                        }
                        .padding(.horizontal)
                        TTProgressHUD(
                            $sendingFlag,
                            config: loadingHUDConfig
                        )
                        TTProgressHUD($hudVisible, config: hudConfig)
                    }
                } else if loadingFlag {
                    LoadingView()
                } else if let error = loadError {
                    ErrorView(error: error, retryAction: fetchGalleryArchive)
                } else {
                    Circle().frame(width: 1).opacity(0.1)
                }
            }
            .navigationBarTitle("Archive")
        }
        .onAppear(perform: fetchGalleryArchive)
    }
}

// MARK: Private Extension
private extension ArchiveView {
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var hathArchives: [GalleryArchive.HathArchive] {
        archive?.hathArchives ?? []
    }

    func onArchiveGridTap(item: GalleryArchive.HathArchive) {
        if item.fileSize != "N/A"
            && item.gpPrice != "N/A"
        {
            selection = item.resolution
        }
    }
    func onDownloadButtonTap() {
        fetchDownloadResponse()
        impactFeedback(style: .soft)
    }
    func performHUD() {
        let isSuccess = !sendFailedFlag
        let type: TTProgressHUDType = isSuccess ? .success : .error
        let title = (isSuccess ? "Success" : "Error").localized
        let caption = response?.localized

        switch type {
        case .success:
            notificFeedback(style: .success)
        case .error:
            notificFeedback(style: .error)
        default:
            break
        }

        hudConfig = TTProgressHUDConfig(
            type: type,
            title: title,
            caption: caption,
            shouldAutoHide: true,
            autoHideInterval: 2
        )
        hudVisible = true
    }

    // MARK: Networking
    func fetchGalleryArchive() {
        loadError = nil
        guard let archiveURL = galleryDetail?.archiveURL, !loadingFlag
        else { return }
        loadingFlag = true

        let token = SubscriptionToken()
        GalleryArchiveRequest(archiveURL: archiveURL)
            .publisher.receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    SwiftyBeaver.error(error)
                    loadError = error
                }
                loadingFlag = false
                token.unseal()
            } receiveValue: { (archive, galleryPoints, credits) in
                self.archive = archive
                if let galleryPoints = galleryPoints, let credits = credits {
                    store.dispatch(.fetchGalleryArchiveFundsDone(
                        result: .success((galleryPoints, credits)))
                    )
                } else if isSameAccount {
                    store.dispatch(.fetchGalleryArchiveFunds(gid: gid))
                }
            }
            .seal(in: token)
    }
    func fetchDownloadResponse() {
        sendFailedFlag = false
        guard let archiveURL = galleryDetail?.archiveURL,
              let resolution = selection, !sendingFlag
        else { return }
        sendingFlag = true

        let token = SubscriptionToken()
        SendDownloadCommandRequest(
            archiveURL: archiveURL,
            resolution: resolution.param
        )
        .publisher
        .receive(on: DispatchQueue.main)
        .sink { completion in
            if case .failure = completion {
                sendFailedFlag = true
            }
            sendingFlag = false
            performHUD()
            token.unseal()
        } receiveValue: { resp in
            switch resp {
            case Defaults.Response.hathClientNotFound,
                 Defaults.Response.hathClientNotOnline,
                 Defaults.Response.invalidResolution, .none:
                sendFailedFlag = true
            default:
                break
            }
            response = resp
            store.dispatch(.fetchGalleryArchiveFunds(gid: gid))
        }
        .seal(in: token)
    }
}

// MARK: ArchiveGrid
private struct ArchiveGrid: View {
    private var isSelected: Bool
    private let archive: GalleryArchive.HathArchive

    private var disabled: Bool {
        archive.fileSize == "N/A"
            || archive.gpPrice == "N/A"
    }
    private var disabledColor: Color {
        .gray.opacity(0.5)
    }
    private var fileSizeColor: Color {
        if disabled {
            return disabledColor
        } else {
            return .gray
        }
    }
    private var borderColor: Color {
        if disabled {
            return disabledColor
        } else {
            return isSelected
                ? .accentColor
                : .gray
        }
    }
    private var environmentColor: Color? {
        disabled ? disabledColor : nil
    }
    private var width: CGFloat {
        Defaults.FrameSize.archiveGridWidth
    }
    private var height: CGFloat {
        width / 1.5
    }

    init(
        isSelected: Bool,
        archive: GalleryArchive.HathArchive
    ) {
        self.isSelected = isSelected
        self.archive = archive
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(archive.resolution.name.localized)
                .fontWeight(.bold)
                .font(.title3)
            VStack {
                Text(archive.fileSize.localized)
                    .fontWeight(.medium)
                    .font(.caption)
                Text(archive.gpPrice.localized)
                    .foregroundColor(fileSizeColor)
                    .font(.caption2)
            }
            .lineLimit(1)
        }
        .foregroundColor(environmentColor)
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: DownloadButton
private struct DownloadButton: View {
    @State private var isPressed = false

    private var isDisabled: Bool
    private var action: () -> Void

    init(
        isDisabled: Bool,
        action: @escaping () -> Void
    ) {
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        HStack {
            Spacer()
            Text("Download To Hath Client")
                .fontWeight(.bold)
                .font(.headline)
                .foregroundColor(textColor)
            Spacer()
        }
        .frame(height: 50)
        .background(backgroundColor)
        .cornerRadius(30)
        .padding(paddingInsets)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: 50,
            pressing: onLongPressing,
            perform: {}
        )
    }
}

private extension DownloadButton {
    var textColor: Color {
        if isDisabled {
            return .white.opacity(0.5)
        } else {
            return isPressed
                ? .white.opacity(0.5)
                : .white
        }
    }
    var backgroundColor: Color {
        if isDisabled {
            return .accentColor.opacity(0.5)
        } else {
            return isPressed
                ? .accentColor.opacity(0.5)
                : .accentColor
        }
    }
    var paddingInsets: EdgeInsets {
        isPadWidth
            ? .init(
                top: 0,
                leading: 0,
                bottom: 30,
                trailing: 0
            )
            : .init(
                top: 0,
                leading: 10,
                bottom: 30,
                trailing: 10
            )
    }

    func onTap() {
        if !isDisabled {
            action()
        }
    }
    func onLongPressing(isPressed: Bool) {
        self.isPressed = isPressed
    }
}

struct ArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store()
        var user = User.empty
//        var gallery = Gallery.empty
//        let hathArchives = ArchiveRes.allCases.map {
//            GalleryArchive.HathArchive(
//                resolution: $0,
//                fileSize: "114 MB",
//                gpPrice: "514 GP"
//            )
//        }
//        let archive = GalleryArchive(
//            hathArchives: hathArchives
//        )

        user.currentGP = "114"
        user.currentCredits = "514"
        store.appState.settings.user = user
        store.appState.environment.isPreview = true

//        store.appState.cachedList.cache(galleries: [gallery])

        return ArchiveView(gid: "")
            .environmentObject(store)
    }
}
