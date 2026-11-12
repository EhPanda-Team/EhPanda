import AnalyticsClient
import AppComponents
import ApplicationClient
public import AppModels
public import ComposableArchitecture
import LibraryClient
public import OSLogExt
import Resources
public import Sharing

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
    // subsystem. `enableTagsExtensionChanged` lets the view report a `@Shared(.setting)` edit so the
    // parent can rebuild the translator (the write itself dispatches no action).
    public enum Delegate: Equatable, Sendable {
        case pushAppActivityLogs
        case enableTagsExtensionChanged
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.setting) public var setting: Setting
        // Drives the native `.fileImporter` presentation for importing custom tag translations.
        @Presents public var destination: Destination.State?
        // Two separate dialogs so each anchors to its own trigger button on iPad (the clear-cache
        // and remove-translations buttons live in different sections).
        @Presents public var clearCacheDialog: ConfirmationDialogState<Dialog>?
        @Presents public var removeTranslationsDialog: ConfirmationDialogState<Dialog>?

        public var loadingState: LoadingState = .idle
        public var diskImageCacheSize = "0 KB"

        /// The level the analytics picker shows; `nil` until the user has chosen one, when the picker shows no
        /// selection (no level is ever a default, D-06a).
        public var analyticsLevel: AnalyticsLevel? { setting.analyticsLevel }

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
        /// The analytics picker's selection (UI-SPEC C-9). Optional only because the picker binds the optional
        /// stored level; `nil` is never offered and changes nothing.
        case analyticsLevelPicked(AnalyticsLevel?)

        case clearImageCacheButtonTapped
        case clearWebImageCache
        case navigateToSystemSetting
        case calculateWebImageDiskCache
        case calculateWebImageDiskCacheDone(UInt?)
    }

    @Dependency(\.analyticsClient) private var analyticsClient
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

            case .clearImageCacheButtonTapped:
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
                    TextState(localized: .clearImageCacheDescription)
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

            // Takes effect at once, with no confirmation either way (UI-SPEC C-9, DD-09a): the level is stored,
            // then applied, so lowering to Minimal terminates the SDK now and `send` already reads the new level.
            // This and `AppReducer` are the only callers of `apply`; the view never calls the client (D-08).
            case .analyticsLevelPicked(let level):
                guard let level, level != state.setting.analyticsLevel else { return .none }
                let previous = state.setting.analyticsLevel
                state.$setting.withLock({ $0.analyticsLevel = level })
                return .run { _ in
                    analyticsClient.apply(level)
                    // Reported once the new level is in force (20-12). A move to Minimal stops the SDK and
                    // Minimal sends no app signal, so `Analytics.to` is only ever Basic or Full.
                    if let previous, level != .minimal {
                        analyticsClient.send(.analyticsLevelChanged(from: previous, toLevel: level))
                    }
                }

            case .clearWebImageCache:
                return .run { send in
                    await libraryClient.removeAllCachedImages()
                    logger.notice("Cleared image cache.")
                    await send(.calculateWebImageDiskCache)
                }

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
                formatter.allowedUnits = [.useKB, .useMB, .useGB]
                formatter.allowsNonnumericFormatting = false
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
