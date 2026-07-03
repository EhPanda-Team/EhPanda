import SwiftUI
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import SFSafeSymbolsExt

// MARK: ToolBar
extension DetailView {
    func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                Button {
                    store.send(.archivesButtonTapped)
                } label: {
                    Label(.archivesAction, systemSymbol: .zipperPage)
                }
                .disabled(store.galleryDetail?.archiveURL == nil || !CookieUtil.didLogin)
                Button {
                    store.send(.torrentsButtonTapped)
                } label: {
                    let base = String(localized: .torrents)
                    let torrentCount = store.galleryDetail?.torrentCount ?? 0
                    let baseWithCount = [base, "(\(torrentCount))"].joined(separator: " ")
                    Label(torrentCount > 0 ? baseWithCount : base, systemSymbol: .leaf)
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
