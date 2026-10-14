import AppComponents
import AppModels
import AppTools
public import ComposableArchitecture
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI

public struct HomeView: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Bindable private var store: StoreOf<HomeReducer>
    @State private var viewportSize: CGSize = .zero
    @State private var paneWidths: HomePaneWidths?

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    // MARK: HomeView
    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HomePrimaryNavigationView(store: store)
                .frame(width: store.isPartiallyOpen ? paneWidths?.left : nil)
                .environment(\.layoutDirection, layoutDirection)
            if store.isPartiallyOpen {
                HomeToplistsNavigationView(store: store)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, layoutDirection)
            }
        }
        .onGeometryChange(for: HomePaneWidths.self) { geometry in
            HomePaneWidths(
                contentWidth: geometry.size.width,
                leftInset: geometry.safeAreaInsets.leading,
                rightInset: geometry.safeAreaInsets.trailing
            )
        } action: { paneWidths = $0 }
        // Navigation ownership follows the physical fold, independently of text direction.
        .environment(\.layoutDirection, .leftToRight)
        .onVisibleViewportChange { viewportSize = $0 }
        .modifier(HomeHingeObservation { store.send(.hingeChanged(isPartiallyOpen: $0)) })
        .background {
            @UIBindable var presentationStore = store
            HomePaneSheet(
                item: $presentationStore.scope(\.$sheet, action: \.sheet),
                viewport: viewportSize,
                isPartiallyOpen: store.isPartiallyOpen,
                side: { $0.side },
                onDismiss: { store.send(.sheetDismissed) }
            ) { sheetStore in
                HomeSheetView(store: sheetStore, viewport: viewportSize, isPartiallyOpen: store.isPartiallyOpen)
            }
        }
    }
}

// MARK: Definition
public enum HomeMiscGridType: CaseIterable, Identifiable, Sendable {
    public var id: String { String(localized: title) }

    case popular
    case watched
    case history
}

extension HomeMiscGridType {
    var title: LocalizedStringResource {
        switch self {
        case .popular:
            return .homeMiscGridTypePopular
        case .watched:
            return .homeMiscGridTypeWatched
        case .history:
            return .homeMiscGridTypeHistory
        }
    }
    var symbol: SFSymbol {
        switch self {
        case .popular:
            return .flame
        case .watched:
            return .tagCircle
        case .history:
            return .clockArrowTriangleheadCounterclockwiseRotate90
        }
    }
}

public enum HomeSectionType: String, CaseIterable, Identifiable, Sendable {
    public var id: String { rawValue }

    case frontpage
    case toplists
}

#Preview("Initial") {
    HomeView(
        store: .init(
            initialState: {
                var state = HomeReducer.State()
                let popular = Gallery.previews(count: 5)
                state.popularGalleries = popular
                state.currentCardID = popular.first?.id ?? ""
                state.frontpageGalleries = Gallery.previews(count: 4)
                return state
            }(),
            reducer: HomeReducer.init
        )
    )
}
