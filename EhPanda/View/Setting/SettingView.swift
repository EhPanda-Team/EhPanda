//
//  SettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct SettingView: View {
    private let store: Store<SettingState, SettingAction>
    @ObservedObject private var viewStore: ViewStore<SettingState, SettingAction>
    private let blurRadius: Double

    init(store: Store<SettingState, SettingAction>, blurRadius: Double) {
        self.store = store
        viewStore = ViewStore(store)
        self.blurRadius = blurRadius
    }

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SettingRoute.allCases) { route in
                        SettingRow(rowType: route) {
                            viewStore.send(.setNavigation($0))
                        }
                    }
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .background(navigationLinks)
            .navigationBarTitle("Setting")
        }
    }
}

// MARK: NavigationLinks
private extension SettingView {
    var navigationLinks: some View {
        ForEach(SettingRoute.allCases) { route in
            NavigationLink("", tag: route, selection: viewStore.binding(\.$route), destination: {
                Group {
                    switch route {
                    case .account:
                        AccountSettingView(
                            store: store.scope(state: \.accountSettingState, action: SettingAction.account),
                            galleryHost: viewStore.binding(\.setting.$galleryHost),
                            showNewDawnGreeting: viewStore.binding(\.setting.$showNewDawnGreeting),
                            bypassesSNIFiltering: viewStore.setting.bypassesSNIFiltering,
                            blurRadius: blurRadius
                        )
                    case .general:
                        GeneralSettingView(
                            store: store.scope(state: \.generalSettingState, action: SettingAction.general),
                            tagTranslatorLoadingState: viewStore.tagTranslatorLoadingState,
                            tagTranslatorEmpty: viewStore.tagTranslator.contents.isEmpty,
                            translatesTags: viewStore.binding(\.setting.$translatesTags),
                            redirectsLinksToSelectedHost: viewStore.binding(\.setting.$redirectsLinksToSelectedHost),
                            detectsLinksFromPasteboard: viewStore.binding(\.setting.$detectsLinksFromPasteboard),
                            backgroundBlurRadius: viewStore.binding(\.setting.$backgroundBlurRadius),
                            autoLockPolicy: viewStore.binding(\.setting.$autoLockPolicy)
                        )
                    case .appearance:
                        AppearanceSettingView(
                            store: store.scope(state: \.appearanceSettingState, action: SettingAction.appearance),
                            preferredColorScheme: viewStore.binding(\.setting.$preferredColorScheme),
                            accentColor: viewStore.binding(\.setting.$accentColor),
                            appIconType: viewStore.binding(\.setting.$appIconType),
                            listMode: viewStore.binding(\.setting.$listMode),
                            showsSummaryRowTags: viewStore.binding(\.setting.$showsSummaryRowTags),
                            summaryRowTagsMaximum: viewStore.binding(\.setting.$summaryRowTagsMaximum)
                        )
                    case .reading:
                        ReadingSettingView(
                            readingDirection: viewStore.binding(\.setting.$readingDirection),
                            prefetchLimit: viewStore.binding(\.setting.$prefetchLimit),
                            prefersLandscape: viewStore.binding(\.setting.$prefersLandscape),
                            contentDividerHeight: viewStore.binding(\.setting.$contentDividerHeight),
                            maximumScaleFactor: viewStore.binding(\.setting.$maximumScaleFactor),
                            doubleTapScaleFactor: viewStore.binding(\.setting.$doubleTapScaleFactor)
                        )
                    case .laboratory:
                        LaboratorySettingView(
                            bypassesSNIFiltering: viewStore.binding(\.setting.$bypassesSNIFiltering)
                        )
                    case .ehpanda:
                        EhPandaView()
                    }
                }
                .tint(viewStore.setting.accentColor)
            })
        }
    }
}

// MARK: SettingRow
private struct SettingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    private let rowType: SettingRoute
    private let tapAction: (SettingRoute) -> Void

    private var color: Color {
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(rowType: SettingRoute, tapAction: @escaping (SettingRoute) -> Void) {
        self.rowType = rowType
        self.tapAction = tapAction
    }

    var body: some View {
        HStack {
            Image(systemSymbol: rowType.symbol)
                .font(.largeTitle).foregroundColor(color)
                .padding(.trailing, 20).frame(width: 45)
            Text(rowType.rawValue.localized).fontWeight(.medium)
                .font(.title3).foregroundColor(color)
            Spacer()
        }
        .contentShape(Rectangle()).padding(.vertical, 10)
        .padding(.horizontal, 20).background(backgroundColor)
        .cornerRadius(10).onTapGesture { tapAction(rowType) }
        .onLongPressGesture(
            minimumDuration: .infinity, maximumDistance: 50,
            pressing: { isPressing = $0 }, perform: {}
        )
    }
}

// MARK: Definition
enum SettingRoute: String, Hashable, Identifiable, CaseIterable {
    var id: String { rawValue }

    case account = "Account"
    case general = "General"
    case appearance = "Appearance"
    case reading = "Reading"
    case laboratory = "Laboratory"
    case ehpanda = "About EhPanda"
}
extension SettingRoute {
    var symbol: SFSymbol {
        switch self {
        case .account:
            return .personFill
        case .general:
            return .switch2
        case .appearance:
            return .circleRighthalfFilled
        case .reading:
            return .newspaperFill
        case .laboratory:
            return .testtube2
        case .ehpanda:
            return .pCircleFill
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(
            store: .init(
                initialState: .init(),
                reducer: settingReducer,
                environment: SettingEnvironment(
                    dfClient: .live,
                    fileClient: .live,
                    loggerClient: .live,
                    hapticClient: .live,
                    libraryClient: .live,
                    cookiesClient: .live,
                    databaseClient: .live,
                    userDefaultsClient: .live,
                    uiApplicationClient: .live,
                    authorizationClient: .live
                )
            ),
            blurRadius: 0
        )
    }
}
