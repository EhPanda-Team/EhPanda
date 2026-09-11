import AppComponents
import ComposableArchitecture
import ReadingSettingFeature
import Resources
import SFSafeSymbols
import SwiftUI

public struct SettingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isPresented) private var isPresented

    @Bindable private var store: StoreOf<SettingReducer>

    public init(store: StoreOf<SettingReducer>) {
        self.store = store
    }

    /// The title mode this screen is designed around, which differs by how it is presented.
    ///
    /// As a tab root the screen owns the whole tab, so its title stays prominent while the list
    /// scrolls: that is what `inlineLarge` buys, and it is the designed appearance. Inside a sheet
    /// the same mode reads wrong — the sheet already carries a title band of its own, and a title
    /// that never yields makes the sheet look like a second, competing navigation bar — so a sheet
    /// takes the ordinary large title that collapses on scroll.
    private var designedTitleDisplayMode: ToolbarTitleDisplayMode {
        isPresented ? .large : .inlineLarge
    }

    // MARK: SettingView
    public var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            ScrollView {
                VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 0) {
                    ForEach(SettingReducer.RootScreen.allCases) { screen in
                        SettingRow(rowType: screen) {
                            store.send(.settingRowTapped($0))
                        }
                    }
                }
                .padding(.vertical, 40).padding(.horizontal)
            }
            .navigationTitle(.RLocalizable.setting)
            .toolbarTitleDisplayMode(designedTitleDisplayMode)
        } destination: { pathStore in
            destination(pathStore)
        }
    }

    // MARK: Destinations
    @ViewBuilder
    private func destination(_ pathStore: StoreOf<SettingPath>) -> some View {
        switch pathStore.case {
        case .account(let accountStore):
            AccountSettingView(store: accountStore)

        case .general(let generalStore):
            GeneralSettingView(
                store: generalStore,
                tagTranslatorLoadingState: store.tagTranslatorLoadingState
            )

        case .appearance(let appearanceStore):
            AppearanceSettingView(store: appearanceStore)

        case .login(let loginStore):
            LoginView(store: loginStore)

        case .ehSetting(let ehSettingStore):
            EhSettingView(store: ehSettingStore)

        case .appActivityLogs(let logsStore):
            AppActivityLogsView(store: logsStore)

        case .download:
            DownloadSettingView()

        case .reading(let readingStore):
            ReadingSettingView(store: readingStore)

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
/// A root row is a `Button` whose label is the row's `Label`, so it carries the button role and
/// its visible title as both the VoiceOver label and the Voice Control name; a tap gesture with a
/// long-press tracking the pressed look gave it neither. The designed pressed background is drawn
/// by ``SettingRowStyle`` from the button's own pressed state instead.
private struct SettingRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private let rowType: SettingReducer.RootScreen
    private let tapAction: (SettingReducer.RootScreen) -> Void

    private var color: Color {
        colorScheme == .light ? Color(.darkGray) : Color(.lightGray)
    }

    init(rowType: SettingReducer.RootScreen, tapAction: @escaping (SettingReducer.RootScreen) -> Void) {
        self.rowType = rowType
        self.tapAction = tapAction
    }

    var body: some View {
        Button {
            tapAction(rowType)
        } label: {
            Label {
                Text(rowType.value)
                    .fontWeight(.medium)
                    .font(.title3)
                    .foregroundStyle(color)
            } icon: {
                Image(systemSymbol: rowType.symbol)
                    .font(.largeTitle)
                    .foregroundStyle(color)
                    .padding(.trailing, 20)
                    .frame(width: 45, height: 45)
            }
        }
        .buttonStyle(SettingRowStyle(color: color))
    }
}

/// The root row's designed look: full-width leading content, the row's own padding, and a tinted
/// background at a tenth of the row colour for exactly as long as the row is pressed. `.plain`
/// has no hook for that background, which is why the row was previously a gesture pair rather
/// than a `Button`; reading `isPressed` here keeps the pressed look and the tap-on-release
/// behaviour of the original while letting the row be a real control.
private struct SettingRowStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(configuration.isPressed ? color.opacity(0.1) : .clear)
            .clipShape(.rect(cornerRadius: 10))
            .contentShape(.rect)
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

#Preview("Initial") {
    SettingView(
        store: .init(initialState: .init(), reducer: SettingReducer.init)
    )
}
