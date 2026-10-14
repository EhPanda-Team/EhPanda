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
    @Environment(\.tabBarPlacement) private var tabBarPlacement
    @Bindable private var store: StoreOf<HomeReducer>
    @State private var paneWidths: HorizontalPaneWidths?

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    private var allowsPadSplitLayout: Bool {
        tabBarPlacement == .topBar && (paneWidths?.contentWidth ?? 0) >= 640
    }

    // MARK: HomeView
    public var body: some View {
        // Only Home owns the two-pane layout. Keep a pushed destination's navigation host
        // against the display edge so its native Back and toolbar items remain available.
        let showsSplitHome = store.usesSplitLayout && store.path.isEmpty
        HStack(alignment: .top, spacing: 0) {
            HomePrimaryNavigationView(store: store, showsSplitHome: showsSplitHome)
                .frame(width: showsSplitHome ? paneWidths?.left : nil)
                .environment(\.layoutDirection, layoutDirection)
            if showsSplitHome {
                HomeToplistsNavigationView(store: store)
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, layoutDirection)
            }
        }
        .onGeometryChange(for: HorizontalPaneWidths.self) { geometry in
            HorizontalPaneWidths(
                contentWidth: geometry.size.width,
                leftInset: geometry.safeAreaInsets.leading,
                rightInset: geometry.safeAreaInsets.trailing
            )
        } action: { paneWidths = $0 }
        .overlay(alignment: .leading) {
            if showsSplitHome, let widths = paneWidths {
                if case .duo = store.device {
                    HomeHingeCrease()
                        .offset(x: widths.left - HomeHingeCrease.width / 2)
                        .ignoresSafeArea(.container, edges: .vertical)
                } else if store.device == .pad {
                    Rectangle()
                        .fill(Color(.opaqueSeparator))
                        .frame(width: 2)
                        .offset(x: widths.left - 1)
                        .ignoresSafeArea(.container, edges: .bottom)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        // Navigation ownership follows the physical fold, independently of text direction.
        .environment(\.layoutDirection, .leftToRight)
        .onVisibleViewportChange { store.send(.viewportChanged($0)) }
        .onChange(of: allowsPadSplitLayout, initial: true) { _, allowsSplit in
            store.send(.padLayoutChanged(allowsSplit: allowsSplit))
        }
        .background {
            WindowDeviceObservation { store.send(.deviceChanged($0)) }
        }
        .background {
            @UIBindable var presentationStore = store
            HomePaneSheet(
                item: $presentationStore.scope(\.$sheet, action: \.sheet),
                viewport: store.viewportSize,
                usesSplitLayout: store.usesSplitLayout,
                side: { $0.side },
                onDismiss: { store.send(.sheetDismissed) }
            ) { sheetStore in
                HomeSheetView(
                    store: sheetStore, viewport: store.viewportSize, usesSplitLayout: store.usesSplitLayout
                )
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
