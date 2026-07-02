import LocalAuthentication
import AppModels
import Resources
import ComposableArchitecture
import AuthorizationClient
import ApplicationClient
import LibraryClient
import DatabaseClient
import OSLogExt

private let logger = Logger(category: .init(describing: GeneralSettingReducer.self))

@Reducer
public struct GeneralSettingReducer: Sendable {
    public enum Dialog: Equatable, Sendable {
        case confirmClearCache
        case confirmRemoveCustomTranslations
    }

    // Pushes handled by SettingReducer, which owns the Setting navigation stack.
    public enum Delegate: Equatable, Sendable {
        case pushAppActivityLogs
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        // Two separate dialogs so each anchors to its own trigger button on iPad (the clear-cache
        // and remove-translations buttons live in different sections).
        @Presents public var clearCacheDialog: ConfirmationDialogState<Dialog>?
        @Presents public var removeTranslationsDialog: ConfirmationDialogState<Dialog>?

        public var loadingState: LoadingState = .idle
        public var diskImageCacheSize = "0 KB"
        public var passcodeNotSet = false

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case clearCacheDialog(PresentationAction<Dialog>)
        case removeTranslationsDialog(PresentationAction<Dialog>)
        case delegate(Delegate)
        case onTranslationsFilePicked(URL)
        case removeCustomTranslationsButtonTapped
        case onRemoveCustomTranslations

        case clearImageCachesButtonTapped
        case clearWebImageCache
        case checkPasscodeSetting
        case navigateToSystemSetting
        case calculateWebImageDiskCache
        case calculateWebImageDiskCacheDone(UInt?)
    }

    @Dependency(\.authorizationClient) private var authorizationClient
    @Dependency(\.applicationClient) private var applicationClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .removeCustomTranslationsButtonTapped:
                state.removeTranslationsDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemoveCustomTranslations) {
                        TextState(L10n.Localizable.ConfirmationDialog.Button.remove)
                    }
                    ButtonState(role: .cancel) {
                        TextState(L10n.Localizable.Common.Button.cancel)
                    }
                } message: {
                    TextState(L10n.Localizable.ConfirmationDialog.Title.removeCustomTranslations)
                }
                return .none

            case .clearImageCachesButtonTapped:
                state.clearCacheDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClearCache) {
                        TextState(L10n.Localizable.ConfirmationDialog.Button.clear)
                    }
                    ButtonState(role: .cancel) {
                        TextState(L10n.Localizable.Common.Button.cancel)
                    }
                } message: {
                    TextState(L10n.Localizable.ConfirmationDialog.Title.clear)
                }
                return .none

            case .removeTranslationsDialog(.presented(.confirmRemoveCustomTranslations)):
                return .send(.onRemoveCustomTranslations)

            case .clearCacheDialog(.presented(.confirmClearCache)):
                return .send(.clearWebImageCache)

            case .removeTranslationsDialog, .clearCacheDialog:
                return .none

            case .onTranslationsFilePicked:
                return .none

            case .onRemoveCustomTranslations:
                return .none

            case .clearWebImageCache:
                return .run { send in
                    async let removeCachedImages: Void =
                        libraryClient.removeAllCachedImages()
                    async let removeImageURLs: Void =
                        databaseClient.removeImageURLs()
                    _ = await (removeCachedImages, removeImageURLs)
                    logger.notice("Cleared image cache.")
                    await send(.calculateWebImageDiskCache)
                }

            case .checkPasscodeSetting:
                state.passcodeNotSet = authorizationClient.passcodeNotSet()
                return .none

            case .navigateToSystemSetting:
                return .run(operation: { _ in await applicationClient.openSettings() })

            case .calculateWebImageDiskCache:
                return .run { send in
                    let size = await libraryClient.calculateWebImageDiskCacheSize()
                    await send(.calculateWebImageDiskCacheDone(size))
                }

            case .calculateWebImageDiskCacheDone(let bytes):
                guard let bytes = bytes else { return .none }
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = .useAll
                state.diskImageCacheSize = formatter.string(fromByteCount: .init(bytes))
                return .none
            }
        }
        .ifLet(\.$clearCacheDialog, action: \.clearCacheDialog)
        .ifLet(\.$removeTranslationsDialog, action: \.removeTranslationsDialog)
    }
}
