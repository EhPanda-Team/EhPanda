import AppComponents
import AppModels
import ClipboardClient
import ComposableArchitecture
import HapticsClient

@Reducer
public struct GalleryInfosReducer: Sendable {
    @ObservableState
    public struct State: Equatable {
        @Presents public var toast: AppAlertState<Never>?
        // Display data captured when this screen is pushed onto the host's gallery stack.
        public var gallery: Gallery
        public var galleryDetail: GalleryDetail

        public init(gallery: Gallery, galleryDetail: GalleryDetail) {
            self.gallery = gallery
            self.galleryDetail = galleryDetail
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
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

            case .toast:
                return .none

            case .copyText(let text):
                state.toast = .copiedToClipboardSucceeded
                return .merge(
                    .run(operation: { _ in clipboardClient.saveText(text) }),
                    .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                )
            }
        }
        .ifLet(\.$toast, action: \.toast)
    }
}
