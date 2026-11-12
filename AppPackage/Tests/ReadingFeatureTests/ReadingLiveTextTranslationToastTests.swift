import AppComponents
import AppModels
import ComposableArchitecture
import Foundation
import LiveTextTranslation
@testable import ReadingFeature
import Sharing
import Testing

// A Live Text translation failure the reader is told about shows as the reader's error toast, with the
// failure's own caption.
// @MainActor sits on members: TCA's `TestStore` is main-actor-isolated.
@Suite
struct ReadingLiveTextTranslationToastTests {
    @MainActor
    @Test(arguments: [
        LiveTextTranslationFailure.unidentifiedLanguage,
        .unsupportedLanguages(source: .init(identifier: "en"), target: .init(identifier: "ja")),
        .translationFailed
    ])
    func aFailureShowsItsCaption(_ failure: LiveTextTranslationFailure) async {
        let store = withDependencies {
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            TestStore(initialState: ReadingReducer.State(gallery: .preview), reducer: ReadingReducer.init)
        }

        await store.send(.liveTextTranslationFailed(failure)) {
            $0.toast = .error(caption: failure.caption)
        }
    }
}
