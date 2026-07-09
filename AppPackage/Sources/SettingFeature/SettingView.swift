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
            AccountSettingView(store: accountStore, blurRadius: blurRadius)

        case .general(let generalStore):
            GeneralSettingView(
                store: generalStore,
                tagTranslatorLoadingState: store.tagTranslatorLoadingState
            )

        case .appearance(let appearanceStore):
            AppearanceSettingView(store: appearanceStore)

        case .login(let loginStore):
            LoginView(store: loginStore, blurRadius: blurRadius)

        case .ehSetting(let ehSettingStore):
            EhSettingView(store: ehSettingStore, blurRadius: blurRadius)

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
