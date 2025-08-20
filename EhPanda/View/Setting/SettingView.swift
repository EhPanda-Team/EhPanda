//
//  SettingView.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct SettingView: View {
    @Bindable private var store: StoreOf<SettingReducer>
    private let blurRadius: Double

    init(store: StoreOf<SettingReducer>, blurRadius: Double) {
        self.store = store
        self.blurRadius = blurRadius
    }

    // MARK: SettingView
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SettingReducer.Route.allCases) { route in
                        SettingRow(rowType: route) {
                            store.send(.setNavigation($0))
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
        NavigationLink(unwrapping: $store.route, case: \.account) { _ in
            AccountSettingView(
                store: store.scope(state: \.accountSettingState, action: \.account),
                galleryHost: $store.setting.galleryHost,
                showsNewDawnGreeting: $store.setting.showsNewDawnGreeting,
                bypassesSNIFiltering: store.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )
            .tint(store.setting.accentColor)
        }
        NavigationLink(unwrapping: $store.route, case: \.general) { _ in
            GeneralSettingView(
                store: store.scope(state: \.generalSettingState, action: \.general),
                tagTranslatorLoadingState: store.tagTranslatorLoadingState,
                tagTranslatorEmpty: store.tagTranslator.translations.isEmpty,
                tagTranslatorHasCustomTranslations: store.tagTranslator.hasCustomTranslations,
                enablesTagsExtension: $store.setting.enablesTagsExtension,
                translatesTags: $store.setting.translatesTags,
                showsTagsSearchSuggestion: $store.setting.showsTagsSearchSuggestion,
                showsImagesInTags: $store.setting.showsImagesInTags,
                redirectsLinksToSelectedHost: $store.setting.redirectsLinksToSelectedHost,
                detectsLinksFromClipboard: $store.setting.detectsLinksFromClipboard,
                backgroundBlurRadius: $store.setting.backgroundBlurRadius,
                autoLockPolicy: $store.setting.autoLockPolicy
            )
            .tint(store.setting.accentColor)
        }
        NavigationLink(unwrapping: $store.route, case: \.appearance) { _ in
            AppearanceSettingView(
                store: store.scope(state: \.appearanceSettingState, action: \.appearance),
                preferredColorScheme: $store.setting.preferredColorScheme,
                accentColor: $store.setting.accentColor,
                appIconType: $store.setting.appIconType,
                listDisplayMode: $store.setting.listDisplayMode,
                showsTagsInList: $store.setting.showsTagsInList,
                listTagsNumberMaximum: $store.setting.listTagsNumberMaximum,
                displaysJapaneseTitle: $store.setting.displaysJapaneseTitle
            )
            .tint(store.setting.accentColor)
        }
        NavigationLink(unwrapping: $store.route, case: \.reading) { _ in
            ReadingSettingView(
                readingDirection: $store.setting.readingDirection,
                prefetchLimit: $store.setting.prefetchLimit,
                enablesLandscape: $store.setting.enablesLandscape,
                contentDividerHeight: $store.setting.contentDividerHeight,
                maximumScaleFactor: $store.setting.maximumScaleFactor,
                doubleTapScaleFactor: $store.setting.doubleTapScaleFactor
            )
            .tint(store.setting.accentColor)
        }
        NavigationLink(unwrapping: $store.route, case: \.laboratory) { _ in
            LaboratorySettingView(
                bypassesSNIFiltering: $store.setting.bypassesSNIFiltering
            )
            .tint(store.setting.accentColor)
        }
        NavigationLink(unwrapping: $store.route, case: \.about) { _ in
            AboutView().tint(store.setting.accentColor)
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
            store: .init(initialState: .init(), reducer: SettingReducer.init),
            blurRadius: 0
        )
    }
}
