import SwiftUI
import AppModels
import Sharing
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppComponents
import ReadingSettingFeature

public struct SettingView: View {
    @Bindable private var store: StoreOf<SettingReducer>
    // Write handle for the drill-down screens whose editors bind `setting` directly; each screen also
    // reads it through its own `@Shared`/`@SharedReader`. Same underlying storage as `store.setting`.
    @Shared(.setting) private var setting: Setting
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
                galleryHost: $store.settingBinding.galleryHost,
                showsNewDawnGreeting: $store.settingBinding.showsNewDawnGreeting,
                bypassesSNIFiltering: store.setting.bypassesSNIFiltering,
                blurRadius: blurRadius
            )

        case .general(let generalStore):
            GeneralSettingView(
                store: generalStore,
                tagTranslatorLoadingState: store.tagTranslatorLoadingState,
                tagTranslatorEmpty: store.tagTranslator.translations.isEmpty,
                tagTranslatorHasCustomTranslations: store.tagTranslator.hasCustomTranslations,
                enablesTagsExtension: $store.settingBinding.enablesTagsExtension,
                translatesTags: $store.settingBinding.translatesTags,
                showsTagsSearchSuggestion: $store.settingBinding.showsTagsSearchSuggestion,
                showsImagesInTags: $store.settingBinding.showsImagesInTags,
                redirectsLinksToSelectedHost: $store.settingBinding.redirectsLinksToSelectedHost,
                detectsLinksFromClipboard: $store.settingBinding.detectsLinksFromClipboard,
                backgroundBlurRadius: $store.settingBinding.backgroundBlurRadius,
                autoLockPolicy: $store.settingBinding.autoLockPolicy
            )

        case .appearance(let appearanceStore):
            AppearanceSettingView(
                store: appearanceStore,
                preferredColorScheme: $store.settingBinding.preferredColorScheme,
                accentColor: $store.settingBinding.accentColor,
                appIconType: $store.settingBinding.appIconType,
                listDisplayMode: $store.settingBinding.listDisplayMode,
                showsTagsInList: $store.settingBinding.showsTagsInList,
                listTagsNumberMaximum: $store.settingBinding.listTagsNumberMaximum,
                displaysJapaneseTitle: $store.settingBinding.displaysJapaneseTitle
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
                downloadThreadLimit: $store.settingBinding.downloadThreadLimit,
                downloadAllowCellular: $store.settingBinding.downloadAllowCellular,
                downloadAutoRetryFailedPages: $store.settingBinding.downloadAutoRetryFailedPages
            )

        case .reading(let readingStore):
            ReadingSettingView(
                readingDirection: Binding($setting.readingDirection),
                prefetchLimit: Binding($setting.prefetchLimit),
                enablesLandscape: Binding($setting.enablesLandscape),
                contentDividerHeight: Binding($setting.contentDividerHeight),
                maximumScaleFactor: Binding($setting.maximumScaleFactor),
                doubleTapScaleFactor: Binding($setting.doubleTapScaleFactor)
            )
            .onChange(of: setting.enablesLandscape) { _, newValue in
                readingStore.send(.enablesLandscapeChanged(newValue))
            }

        case .laboratory(let laboratoryStore):
            LaboratorySettingView(store: laboratoryStore)

        case .about:
            AboutView()

        case .appIcon(let appIconStore):
            AppIconView(store: appIconStore)
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
    var value: LocalizedStringResource {
        switch self {
        case .account:
            return .settingStateRouteAccount
        case .general:
            return .settingStateRouteGeneral
        case .appearance:
            return .settingStateRouteAppearance
        case .download:
            return .settingStateRouteDownload
        case .reading:
            return .settingStateRouteReading
        case .laboratory:
            return .settingStateRouteLaboratory
        case .about:
            return .settingStateRouteAbout
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
