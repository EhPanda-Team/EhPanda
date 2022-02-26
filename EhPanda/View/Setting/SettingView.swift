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
                    ForEach(SettingState.Route.allCases) { route in
                        SettingRow(rowType: route) {
                            viewStore.send(.setNavigation($0))
                        }
                    }
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .background(navigationLinks)
            .navigationTitle(R.string.localizable.settingViewTitleSetting())
        }
    }
}

// MARK: NavigationLinks
private extension SettingView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SettingState.Route.account) { _ in
            AccountSettingView(
                store: store.scope(state: \.accountSettingState, action: SettingAction.account),
                galleryHost: viewStore.binding(\.$setting.galleryHost),
                showsNewDawnGreeting: viewStore.binding(\.$setting.showsNewDawnGreeting),
                bypassesSNIFiltering: viewStore.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SettingState.Route.general) { _ in
            GeneralSettingView(
                store: store.scope(state: \.generalSettingState, action: SettingAction.general),
                tagTranslatorLoadingState: viewStore.tagTranslatorLoadingState,
                tagTranslatorEmpty: viewStore.tagTranslator.translations.isEmpty,
                tagTranslatorHasCustomTranslations: viewStore.tagTranslator.hasCustomTranslations,
                enablesTagsExtension: viewStore.binding(\.$setting.enablesTagsExtension),
                translatesTags: viewStore.binding(\.$setting.translatesTags),
                showsTagsSearchSuggestion: viewStore.binding(\.$setting.showsTagsSearchSuggestion),
                showsImagesInTags: viewStore.binding(\.$setting.showsImagesInTags),
                redirectsLinksToSelectedHost: viewStore.binding(\.$setting.redirectsLinksToSelectedHost),
                detectsLinksFromClipboard: viewStore.binding(\.$setting.detectsLinksFromClipboard),
                backgroundBlurRadius: viewStore.binding(\.$setting.backgroundBlurRadius),
                autoLockPolicy: viewStore.binding(\.$setting.autoLockPolicy)
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SettingState.Route.appearance) { _ in
            AppearanceSettingView(
                store: store.scope(state: \.appearanceSettingState, action: SettingAction.appearance),
                preferredColorScheme: viewStore.binding(\.$setting.preferredColorScheme),
                accentColor: viewStore.binding(\.$setting.accentColor),
                appIconType: viewStore.binding(\.$setting.appIconType),
                listDisplayMode: viewStore.binding(\.$setting.listDisplayMode),
                showsTagsInList: viewStore.binding(\.$setting.showsTagsInList),
                listTagsNumberMaximum: viewStore.binding(\.$setting.listTagsNumberMaximum),
                displaysJapaneseTitle: viewStore.binding(\.$setting.displaysJapaneseTitle)
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SettingState.Route.reading) { _ in
            ReadingSettingView(
                readingDirection: viewStore.binding(\.$setting.readingDirection),
                prefetchLimit: viewStore.binding(\.$setting.prefetchLimit),
                enablesLandscape: viewStore.binding(\.$setting.enablesLandscape),
                contentDividerHeight: viewStore.binding(\.$setting.contentDividerHeight),
                maximumScaleFactor: viewStore.binding(\.$setting.maximumScaleFactor),
                doubleTapScaleFactor: viewStore.binding(\.$setting.doubleTapScaleFactor)
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SettingState.Route.laboratory) { _ in
            LaboratorySettingView(
                bypassesSNIFiltering: viewStore.binding(\.$setting.bypassesSNIFiltering)
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SettingState.Route.ehpanda) { _ in
            EhPandaView().tint(viewStore.setting.accentColor)
        }
    }
}

// MARK: SettingRow
private struct SettingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    private let rowType: SettingState.Route
    private let tapAction: (SettingState.Route) -> Void

    private var color: Color {
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(rowType: SettingState.Route, tapAction: @escaping (SettingState.Route) -> Void) {
        self.rowType = rowType
        self.tapAction = tapAction
    }

    var body: some View {
        HStack {
            Image(systemSymbol: rowType.symbol)
                .font(.largeTitle).foregroundColor(color)
                .padding(.trailing, 20).frame(width: 45)
            Text(rowType.value).fontWeight(.medium)
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
extension SettingState.Route {
    var value: String {
        switch self {
        case .account:
            return R.string.localizable.enumSettingStateRouteValueAccount()
        case .general:
            return R.string.localizable.enumSettingStateRouteValueGeneral()
        case .appearance:
            return R.string.localizable.enumSettingStateRouteValueAppearance()
        case .reading:
            return R.string.localizable.enumSettingStateRouteValueReading()
        case .laboratory:
            return R.string.localizable.enumSettingStateRouteValueLaboratory()
        case .ehpanda:
            return R.string.localizable.enumSettingStateRouteValueEhPanda()
        }
    }
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
                    deviceClient: .live,
                    loggerClient: .live,
                    hapticClient: .live,
                    libraryClient: .live,
                    cookiesClient: .live,
                    databaseClient: .live,
                    clipboardClient: .live,
                    appDelegateClient: .live,
                    userDefaultsClient: .live,
                    uiApplicationClient: .live,
                    authorizationClient: .live
                )
            ),
            blurRadius: 0
        )
    }
}
