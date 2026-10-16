import AppComponents
public import ComposableArchitecture
import DetailFeature
public import SwiftUI

public struct DownloadInspectionView: View {
    private let store: StoreOf<DownloadsReducer.InspectionFeature>

    private let closeAction: () -> Void

    public init(store: StoreOf<DownloadsReducer.InspectionFeature>, closeAction: @escaping () -> Void) {
        self.store = store
        self.closeAction = closeAction
    }

    public var body: some View {
        Group {
            switch store.case {
            case .details(let detailStore):
                GallerySheetView(store: detailStore, showsCloseButton: true, closeAction: closeAction)
            case .pages(let pagesStore):
                NavigationStack {
                    DownloadInspectorView(store: pagesStore)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .privacyMask()
        .accessibilityIdentifier("download-native-inspector")
    }
}
