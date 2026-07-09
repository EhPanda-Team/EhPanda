import LocalAuthentication
import AppModels
import Resources
import ComposableArchitecture
import AuthorizationClient
import ApplicationClient
import LibraryClient
import OSLogExt
import AppComponents

private let logger = Logger(category: .init(describing: GeneralSettingReducer.self))

@Reducer
public struct GeneralSettingReducer: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case importTranslations
    }

    public enum Dialog: Equatable, Sendable {
        case confirmClearCache
        case confirmRemoveCustomTranslations
    }

    // Handled by SettingReducer, which owns the Setting navigation stack and the tag-translator
    // subsystem. `enablesTagsExtensionChanged` lets the view report a `@Shared(.setting)` edit so the
    // parent can rebuild the translator (the write itself dispatches no action).
    public enum Delegate: Equatable, Sendable {
        case pushAppActivityLogs
        case enablesTagsExtensionChanged
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        // Drives the native `.fileImporter` presentation for importing custom tag translations.
        @Presents public var destination: Destination.State?
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
        case destination(PresentationAction<Destination.Action>)
        case clearCacheDialog(PresentationAction<Dialog>)
        case removeTranslationsDialog(PresentationAction<Dialog>)
        case delegate(Delegate)
        case importCustomTranslationsButtonTapped
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
    @Dependency(\.libraryClient) private var libraryClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .destination:
                return .none

            case .delegate:
                return .none

            case .importCustomTranslationsButtonTapped:
                state.destination = .importTranslations
                return .none

            case .removeCustomTranslationsButtonTapped:
                state.removeTranslationsDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .remove)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemoveCustomTranslations) {
                        TextState(localized: .remove)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .removeCustomTranslationsConfirmation)
                }
                return .none

            case .clearImageCachesButtonTapped:
                state.clearCacheDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .RLocalizable.clear)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClearCache) {
                        TextState(localized: .RLocalizable.clear)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .RLocalizable.clearDescription)
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
                    await libraryClient.removeAllCachedImages()
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
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$clearCacheDialog, action: \.clearCacheDialog)
        .ifLet(\.$removeTranslationsDialog, action: \.removeTranslationsDialog)
    }
}

extension GeneralSettingReducer.Destination.State: Equatable, Sendable {}
extension GeneralSettingReducer.Destination.Action: Equatable, Sendable {}
