//
//  ArchiveView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/06.
//

import SwiftUI
import TTProgressHUD

struct ArchiveView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var selection: ArchiveRes?

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )
    private var loadingHUDConfig = TTProgressHUDConfig(
        type: .loading,
        title: "Communicating...".localized(),
        hapticsEnabled: false
    )
    private let gridItems = [
        GridItem(.adaptive(minimum: 150, maximum: 200))
    ]

    private let gid: String

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
                            LazyVGrid(columns: gridItems, spacing: 10) {
                                ForEach(hathArchives) { hathArchive in
                                    ArchiveGrid(
                                        isSelected: selection
                                            == hathArchive.resolution,
                                        archive: hathArchive
                                    )
                                    .onTapGesture(perform: {
                                        onArchiveGridTap(hathArchive)
                                    })
                                }
                            }
                            .padding(.top, 40)

                            Spacer()

                            if isSameAccount,
                               let galleryPoints = currentGP,
                               let credits = currentCredits
                            {
                                BalanceView(galleryPoints: galleryPoints, credits: credits)
                            }
                            DownloadButton(
                                isDisabled: selection == nil,
                                action: onDownloadButtonTap
                            )
                        }
                        .padding(.horizontal)
                        TTProgressHUD(
                            detailInfoBinding.downloadCommandSending,
                            config: loadingHUDConfig
                        )
                        TTProgressHUD($hudVisible, config: hudConfig)
                    }
                } else if detailInfo.mangaArchiveLoading {
                    LoadingView()
                } else {
                    NetworkErrorView(retryAction: fetchMangaArchive)
                }
            }
            .navigationBarTitle("Archive")
            .onChange(
                of: detailInfo.downloadCommandSending,
                perform: onRespChange
            )
            .onChange(
                of: hudVisible,
                perform: onHUDVisibilityChange
            )
        }
        .onAppear(perform: onAppear)
    }
}

private extension ArchiveView {
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[gid]?.detail
    }
    var archive: MangaArchive? {
        mangaDetail?.archive
    }
    var hathArchives: [MangaArchive.HathArchive] {
        archive?.hathArchives ?? []
    }

    func onAppear() {
        fetchMangaArchive()
    }
    func onArchiveGridTap(_ item: MangaArchive.HathArchive) {
        if item.fileSize != "N/A"
            && item.gpPrice != "N/A"
        {
            selection = item.resolution
        }
    }
    func onDownloadButtonTap() {
        if let res = selection?.param {
            store.dispatch(.sendDownloadCommand(gid: gid, resolution: res))
            impactFeedback(style: .soft)
        }
    }
    func onRespChange<E: Equatable>(_ value: E) {
        if let sending = value as? Bool,
           sending == false
        {
            let isSuccess = !detailInfo.downloadCommandFailed
            let type: TTProgressHUDType = isSuccess ? .success : .error
            let title = (isSuccess ? "Success" : "Error").localized()
            let caption = detailInfo.downloadCommandResponse?.localized()

            switch type {
            case .success:
                notificFeedback(style: .success)
            case .error:
                notificFeedback(style: .error)
            default:
                print(type)
            }

            hudConfig = TTProgressHUDConfig(
                type: type,
                title: title,
                caption: caption,
                shouldAutoHide: true,
                autoHideInterval: 2,
                hapticsEnabled: false
            )
            hudVisible.toggle()
        }
    }
    func onHUDVisibilityChange<E: Equatable>(_ value: E) {
        if let isVisible = value as? Bool,
           isVisible == false
        {
            store.dispatch(.resetDownloadCommandResponse)
        }
    }

    func fetchMangaArchive() {
        store.dispatch(.fetchMangaArchive(gid: gid))
        if currentGP == nil
            || currentCredits == nil
        {
            store.dispatch(.fetchMangaArchiveFunds(gid: gid))
        }
    }
}

// MARK: ArchiveGrid
private struct ArchiveGrid: View {
    private var isSelected: Bool
    private let archive: MangaArchive.HathArchive

    private var disabled: Bool {
        archive.fileSize == "N/A"
            || archive.gpPrice == "N/A"
    }
    private var disabledColor: Color {
        Color.gray.opacity(0.5)
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

    init(isSelected: Bool, archive: MangaArchive.HathArchive) {
        self.isSelected = isSelected
        self.archive = archive
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(archive.resolution.rawValue.localized())
                .fontWeight(.bold)
                .font(.title3)
            VStack {
                Text(archive.fileSize.localized())
                    .fontWeight(.medium)
                    .font(.caption)
                Text(archive.gpPrice.localized())
                    .foregroundColor(fileSizeColor)
                    .font(.caption2)
            }
            .lineLimit(1)
        }
        .foregroundColor(environmentColor)
        .frame(width: 150, height: 100)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: BalanceView
private struct BalanceView: View {
    private let galleryPoints: String
    private let credits: String

    init(galleryPoints: String, credits: String) {
        self.galleryPoints = galleryPoints
        self.credits = credits
    }

    var body: some View {
        HStack(spacing: 15) {
            HStack(spacing: 3) {
                Image(systemName: "g.circle.fill")
                Text(galleryPoints)
            }
            HStack(spacing: 3) {
                Image(systemName: "c.circle.fill")
                Text(credits)
            }
        }
        .font(.headline)
        .padding()
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
            return Color.white.opacity(0.5)
        } else {
            return isPressed
                ? Color.white.opacity(0.5)
                : .white
        }
    }
    var backgroundColor: Color {
        if isDisabled {
            return Color.accentColor.opacity(0.5)
        } else {
            return isPressed
                ? Color.accentColor.opacity(0.5)
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
    func onLongPressing(_ isPressed: Bool) {
        self.isPressed = isPressed
    }
}

private struct ArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store()
        var user = User.empty
        var manga = Manga.empty
        let hathArchives = ArchiveRes.allCases.map {
            MangaArchive.HathArchive(
                resolution: $0,
                fileSize: "114 MB",
                gpPrice: "514 GP"
            )
        }
        let archive = MangaArchive(
            hathArchives: hathArchives
        )

        user.currentGP = "114"
        user.currentCredits = "514"
        manga.detail?.archive = archive
        store.appState.settings.user = user
        store.appState.environment.isPreview = true
        store.appState.cachedList.items?["mangaForTest"] = manga

        return ArchiveView(gid: "mangaForTest")
            .environmentObject(store)
    }
}
