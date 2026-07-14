import SwiftUI
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import SFSafeSymbolsExt
import CookieClient

// MARK: ToolBar
extension DetailView {
    func toolbar() -> some ToolbarContent {
        @Dependency(\.cookieClient) var cookieClient
        return CustomToolbarItem {
            ToolbarFeaturesMenu {
                Button {
                    store.send(.archivesButtonTapped)
                } label: {
                    Label(.archivesAction, systemSymbol: .zipperPage)
                }
                .disabled(store.galleryDetail?.archiveURL == nil || !cookieClient.didLogin)
                Button {
                    store.send(.torrentsButtonTapped)
                } label: {
                    let torrentCount = store.galleryDetail?.torrentCount ?? 0
                    let title: LocalizedStringResource = torrentCount > 0
                        ? .torrentsCount(count: torrentCount) : .torrents
                    Label(title, systemSymbol: .leaf)
                }
                .disabled((store.galleryDetail?.torrentCount ?? 0 > 0) != true)
                Button {
                    if let galleryURL = store.gallery.galleryURL {
                        store.send(.shareButtonTapped(galleryURL))
                    }
                } label: {
                    Label(.RLocalizable.share, systemSymbol: .squareAndArrowUp)
                }
            }
            .disabled(store.galleryDetail == nil || store.loadingState == .loading)
        }
    }
}
