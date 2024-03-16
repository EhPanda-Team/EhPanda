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
    private let store: StoreOf<SettingReducer>
    @ObservedObject private var viewStore: ViewStoreOf<SettingReducer>
    private let blurRadius: Double

    init(store: StoreOf<SettingReducer>, blurRadius: Double) {
        self.store = store
        viewStore = ViewStore(store, observe: { $0 })
        self.blurRadius = blurRadius
    }

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SettingReducer.Route.allCases) { route in
                        SettingRow(rowType: route) {
                            viewStore.send(.setNavigation($0))
                        }
                    }
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .background(navigationLinks)
            .navigationTitle(L10n.Localizable.SettingView.Title.setting)
        }
    }
}

// MARK: NavigationLinks
private extension SettingView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: viewStore.$route, case: /SettingReducer.Route.account) { _ in
            AccountSettingView(
                store: store.scope(state: \.accountSettingState, action: SettingReducer.Action.account),
                galleryHost: viewStore.$setting.galleryHost,
                showsNewDawnGreeting: viewStore.$setting.showsNewDawnGreeting,
                bypassesSNIFiltering: viewStore.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.$route, case: /SettingReducer.Route.general) { _ in
            GeneralSettingView(
                store: store.scope(state: \.generalSettingState, action: SettingReducer.Action.general),
                tagTranslatorLoadingState: viewStore.tagTranslatorLoadingState,
                tagTranslatorEmpty: viewStore.tagTranslator.translations.isEmpty,
                tagTranslatorHasCustomTranslations: viewStore.tagTranslator.hasCustomTranslations,
                enablesTagsExtension: viewStore.$setting.enablesTagsExtension,
                translatesTags: viewStore.$setting.translatesTags,
                showsTagsSearchSuggestion: viewStore.$setting.showsTagsSearchSuggestion,
                showsImagesInTags: viewStore.$setting.showsImagesInTags,
                redirectsLinksToSelectedHost: viewStore.$setting.redirectsLinksToSelectedHost,
                detectsLinksFromClipboard: viewStore.$setting.detectsLinksFromClipboard,
                backgroundBlurRadius: viewStore.$setting.backgroundBlurRadius,
                autoLockPolicy: viewStore.$setting.autoLockPolicy
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.$route, case: /SettingReducer.Route.appearance) { _ in
            AppearanceSettingView(
                store: store.scope(state: \.appearanceSettingState, action: SettingReducer.Action.appearance),
                preferredColorScheme: viewStore.$setting.preferredColorScheme,
                accentColor: viewStore.$setting.accentColor,
                appIconType: viewStore.$setting.appIconType,
                listDisplayMode: viewStore.$setting.listDisplayMode,
                showsTagsInList: viewStore.$setting.showsTagsInList,
                listTagsNumberMaximum: viewStore.$setting.listTagsNumberMaximum,
                displaysJapaneseTitle: viewStore.$setting.displaysJapaneseTitle
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.$route, case: /SettingReducer.Route.reading) { _ in
            ReadingSettingView(
                readingDirection: viewStore.$setting.readingDirection,
                prefetchLimit: viewStore.$setting.prefetchLimit,
                enablesLandscape: viewStore.$setting.enablesLandscape,
                contentDividerHeight: viewStore.$setting.contentDividerHeight,
                maximumScaleFactor: viewStore.$setting.maximumScaleFactor,
                doubleTapScaleFactor: viewStore.$setting.doubleTapScaleFactor
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.$route, case: /SettingReducer.Route.laboratory) { _ in
            LaboratorySettingView(
                bypassesSNIFiltering: viewStore.$setting.bypassesSNIFiltering
            )
            .tint(viewStore.setting.accentColor)
        }
        NavigationLink(unwrapping: viewStore.$route, case: /SettingReducer.Route.about) { _ in
            AboutView().tint(viewStore.setting.accentColor)
        }
    }
}

// MARK: SettingRow
private struct SettingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    private let rowType: SettingReducer.Route
    private let tapAction: (SettingReducer.Route) -> Void

    private var color: Color {
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(rowType: SettingReducer.Route, tapAction: @escaping (SettingReducer.Route) -> Void) {
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
extension SettingReducer.Route {
    var value: String {
        switch self {
        case .account:
            return L10n.Localizable.Enum.SettingStateRoute.Value.account
        case .general:
            return L10n.Localizable.Enum.SettingStateRoute.Value.general
        case .appearance:
            return L10n.Localizable.Enum.SettingStateRoute.Value.appearance
        case .reading:
            return L10n.Localizable.Enum.SettingStateRoute.Value.reading
        case .laboratory:
            return L10n.Localizable.Enum.SettingStateRoute.Value.laboratory
        case .about:
            return L10n.Localizable.Enum.SettingStateRoute.Value.about
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
        case .about:
            return .pCircleFill
        }
    }
}

struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SettingView(
            store: .init(initialState: .init()) {
                SettingReducer()
            },
            blurRadius: 0
        )
    }
}
