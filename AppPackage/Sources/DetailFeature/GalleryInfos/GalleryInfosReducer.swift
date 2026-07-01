import AppModels
import ComposableArchitecture
import HapticsClient
import ClipboardClient
import TTProgressHUDExt

@Reducer
public struct GalleryInfosReducer: Sendable {
    @CasePathable
    public enum Route: Sendable {
        case hud
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        public var hudConfig: ProgressHUDConfigState = .copiedToClipboardSucceeded
        // Display data captured when this screen is pushed onto the host's gallery stack.
        public var gallery: Gallery = .empty
        public var galleryDetail: GalleryDetail = .empty

        public init(gallery: Gallery = .empty, galleryDetail: GalleryDetail = .empty) {
            self.gallery = gallery
            self.galleryDetail = galleryDetail
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case copyText(String)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .copyText(let text):
                state.route = .hud
                return .merge(
                    .run(operation: { _ in clipboardClient.saveText(text) }),
                    .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                )
            }
        }
    }
}
