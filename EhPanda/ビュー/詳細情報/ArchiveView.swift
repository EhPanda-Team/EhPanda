//
//  ArchiveView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/06.
//

import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var store: Store
    @State var selection: ArchiveRes? = nil
    
    let id: String
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[id]?.detail
    }
    var archive: MangaArchive? {
        mangaDetail?.archive
    }
    var currentGP: String? {
        archive?.currentGP
    }
    var currentCredits: String? {
        archive?.currentCredits
    }
    var hathArchives: [MangaArchive.HathArchive] {
        archive?.hathArchives ?? []
    }
    let gridItems = [
        GridItem(.adaptive(minimum: 150, maximum: 200))
    ]
    
    // MARK: ArchiveView本体
    var body: some View {
        NavigationView {
            Group {
                if !hathArchives.isEmpty {
                    VStack {
//                        if let gp = currentGP,
//                           let credits = currentCredits
//                        {
//                            HStack {
//                                Text(gp)
//                                Text(credits)
//
//                            }
//                        }
                        LazyVGrid(columns: gridItems, spacing: 10) {
                            ForEach(hathArchives) { hathArchive in
                                ArchiveGrid(
                                    selected: selection
                                        == hathArchive.resolution,
                                    archive: hathArchive
                                )
                                .onTapGesture(perform: {
                                    onArchiveGridTap(hathArchive)
                                })
                            }
                        }
                        .padding(.top, 30)
                        Spacer()
                        DownloadButton(
                            isDisabled: selection == nil,
                            action: onDownloadButtonTap
                        )
                    }
                    .padding(.horizontal)
                } else if detailInfo.mangaArchiveLoading {
                    LoadingView()
                } else {
                    NetworkErrorView(retryAction: fetchMangaArchive)
                }
            }
            .navigationBarTitle("アーカイブ")
            .onAppear(perform: onAppear)
        }
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
        
    }
    
    func fetchMangaArchive() {
        store.dispatch(.fetchMangaArchive(id: id))
        if archive?.currentGP == nil
            || archive?.currentCredits == nil
        {
            store.dispatch(.fetchMangaArchiveFunds(id: id))
        }
    }
}

// MARK: ArchiveGrid
private struct ArchiveGrid: View {
    var selected: Bool
    let archive: MangaArchive.HathArchive
    
    var disabled: Bool {
        archive.fileSize == "N/A"
            || archive.gpPrice == "N/A"
    }
    var disabledColor: Color {
        Color.gray.opacity(0.5)
    }
    var fileSizeColor: Color {
        if disabled {
            return disabledColor
        } else {
            return .gray
        }
    }
    var borderColor: Color {
        if disabled {
            return disabledColor
        } else {
            return selected
                ? .accentColor
                : .gray
        }
    }
    var environmentColor: Color? {
        disabled ? disabledColor : nil
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text(archive.resolution.rawValue.lString())
                .fontWeight(.bold)
                .font(.title3)
            VStack {
                Text(archive.gpPrice.lString())
                    .fontWeight(.medium)
                    .font(.caption)
                Text(archive.fileSize.lString())
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

// MARK: DownloadButton
private struct DownloadButton: View {
    @State var isPressed = false
    
    var isDisabled: Bool
    var action: () -> ()
    
    var textColor: Color {
        if isDisabled {
            return .gray
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
        isPad ? .init(top: 30, leading: 0, bottom: 0, trailing: 0)
            : .init(top: 30, leading: 10, bottom: 0, trailing: 10)
    }
    
    var body: some View {
        HStack {
            Spacer()
            Text("Hathサーバーにダウンロード")
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
    
    func onTap() {
        if !isDisabled {
            action()
        }
    }
    func onLongPressing(_ isPressed: Bool) {
        self.isPressed = isPressed
    }
}
