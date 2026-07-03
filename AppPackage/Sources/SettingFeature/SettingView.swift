import SwiftUI
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppComponents
import ReadingSettingFeature

public struct SettingView: View {
    @Bindable private var store: StoreOf<SettingReducer>
    private let blurRadius: Double

    public init(store: StoreOf<SettingReducer>, blurRadius: Double) {
        self.store = store
        self.blurRadius = blurRadius
    }

    // MARK: SettingView
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SettingReducer.RootScreen.allCases) { screen in
                        SettingRow(rowType: screen) {
                            store.send(.settingRowTapped($0))
                        }
                    }
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .navigationTitle(.RLocalizable.setting)
        } destination: { pathStore in
            destination(pathStore)
                .tint(store.setting.accentColor)
        }
    }

    // MARK: Destinations
    @ViewBuilder
    private func destination(_ pathStore: StoreOf<SettingPath>) -> some View {
        switch pathStore.case {
        case .account(let accountStore):
            AccountSettingView(
                store: accountStore,
                galleryHost: $store.setting.galleryHost,
                showsNewDawnGreeting: $store.setting.showsNewDawnGreeting,
                bypassesSNIFiltering: store.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )

        case .general(let generalStore):
            GeneralSettingView(
                store: generalStore,
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

        case .appearance(let appearanceStore):
            AppearanceSettingView(
                store: appearanceStore,
                preferredColorScheme: $store.setting.preferredColorScheme,
                accentColor: $store.setting.accentColor,
                appIconType: $store.setting.appIconType,
                listDisplayMode: $store.setting.listDisplayMode,
                showsTagsInList: $store.setting.showsTagsInList,
                listTagsNumberMaximum: $store.setting.listTagsNumberMaximum,
                displaysJapaneseTitle: $store.setting.displaysJapaneseTitle
            )

        case .login(let loginStore):
            LoginView(
                store: loginStore,
                bypassesSNIFiltering: store.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )

        case .ehSetting(let ehSettingStore):
            EhSettingView(
                store: ehSettingStore,
                bypassesSNIFiltering: store.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )

        case .appActivityLogs(let logsStore):
            AppActivityLogsView(store: logsStore)

        case .download:
            DownloadSettingView(
                downloadThreadLimit: $store.setting.downloadThreadLimit,
                downloadAllowCellular: $store.setting.downloadAllowCellular,
                downloadAutoRetryFailedPages: $store.setting.downloadAutoRetryFailedPages
            )

        case .reading:
            ReadingSettingView(
                readingDirection: $store.setting.readingDirection,
                prefetchLimit: $store.setting.prefetchLimit,
                enablesLandscape: $store.setting.enablesLandscape,
                contentDividerHeight: $store.setting.contentDividerHeight,
                maximumScaleFactor: $store.setting.maximumScaleFactor,
                doubleTapScaleFactor: $store.setting.doubleTapScaleFactor
            )

        case .laboratory:
            LaboratorySettingView(
                bypassesSNIFiltering: $store.setting.bypassesSNIFiltering
            )

        case .about:
            AboutView()

        case .appIcon:
            AppIconView(appIconType: $store.setting.appIconType)
        }
    }
}

// MARK: SettingRow
private struct SettingRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressing = false

    private let rowType: SettingReducer.RootScreen
    private let tapAction: (SettingReducer.RootScreen) -> Void

    private var color: Color {
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }
    private var backgroundColor: Color {
        isPressing ? color.opacity(0.1) : .clear
    }

    init(rowType: SettingReducer.RootScreen, tapAction: @escaping (SettingReducer.RootScreen) -> Void) {
        self.rowType = rowType
        self.tapAction = tapAction
    }

    var body: some View {
        HStack {
            Image(systemSymbol: rowType.symbol)
                .font(.largeTitle).foregroundColor(color)
                .padding(.trailing, 20).frame(width: 45, height: 45)
            Text(rowType.value).fontWeight(.medium)
                .font(.title3).foregroundColor(color)
            Spacer()
        }
        .contentShape(.rect).padding(.vertical, 10)
        .padding(.horizontal, 20).background(backgroundColor)
        .cornerRadius(10).onTapGesture { tapAction(rowType) }
        .onLongPressGesture(
            minimumDuration: .infinity, maximumDistance: 50,
            pressing: { isPressing = $0 }, perform: {}
        )
    }
}

// MARK: Definition
extension SettingReducer.RootScreen {
    var value: String {
        switch self {
        case .account:
            return String(localized: .settingStateRouteAccount)
        case .general:
            return String(localized: .settingStateRouteGeneral)
        case .appearance:
            return String(localized: .settingStateRouteAppearance)
        case .download:
            return String(localized: .settingStateRouteDownload)
        case .reading:
            return String(localized: .settingStateRouteReading)
        case .laboratory:
            return String(localized: .settingStateRouteLaboratory)
        case .about:
            return String(localized: .settingStateRouteAbout)
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
        case .download:
            return .squareAndArrowDownOnSquare
        case .reading:
            return .newspaper
        case .laboratory:
            return .testtube2
        case .about:
            return .infoCircle
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
