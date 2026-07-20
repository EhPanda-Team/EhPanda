@testable import AppFeature
import AppModels
import AppTools
@testable import ClipboardClient
import ComposableArchitecture
import CustomDump
import Foundation
import Testing
@testable import UserDefaultsClient

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct PresentationFeatureTests {
    @Test(arguments: [
        GalleryFailureRouteFixture(
            url: "https://e-hentai.org/g/123/secret-token?next=private",
            secret: "secret-token"
        ),
        GalleryFailureRouteFixture(
            url: "https://exhentai.org/s/secret-key/456-7?next=private",
            secret: "secret-key"
        )
    ])
    @MainActor
    private func galleryFailureToastUsesSanitizedContext(fixture: GalleryFailureRouteFixture) async throws {
        let url = try #require(URL(string: fixture.url))
        let context = Context.galleryFailure(
            url: url,
            action: "Fetch gallery",
            reason: AppError.networkingFailed.localizedDescription
        )
        let errorInfo = ErrorInfo(error: .networkingFailed, context: context)
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init
        )

        await store.send(.fetchGalleryDone(url: url, result: .failure(.networkingFailed)))
        await store.receive(\.setToast, timeout: .seconds(1)) {
            $0.toast = .error(errorInfo)
        }

        let values = context.values.map(\.displayValue)
        #expect(values.contains(where: { $0.contains(fixture.secret) }) == false)
        #expect(values.contains(where: { $0.contains(url.path) }) == false)
        #expect(values.contains(where: { $0.contains("next=private") }) == false)
        #expect(values.contains(where: { $0.contains(url.absoluteString) }) == false)
    }

    @MainActor
    @Test
    func presentErrorInfoRoutesToErrorInfoDestination() async {
        let errorInfo = ErrorInfo(
            error: .parseFailed,
            context: [.action: "test"]
        )
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init
        )

        await store.send(.presentErrorInfo(errorInfo)) {
            $0.destination = .errorInfo(errorInfo)
        }
    }

    // Proves the read routes through the injected UserDefaultsClient, not UserDefaults.standard:
    // the injected read equals the clipboard change count, so the guard short-circuits and no write
    // occurs — even though the process-global holds a conflicting value that would force a write if
    // it were consulted.
    @MainActor
    @Test
    func injectedReadSuppressesWriteDespiteConflictingProcessGlobal() async {
        let recordedWrites = LockIsolated<[Int]>([])
        let matchingChangeCount = 42

        await withSeededProcessGlobal(conflicting: 999) {
            let store = TestStore(
                initialState: PresentationFeature.State(),
                reducer: PresentationFeature.init,
                withDependencies: {
                    $0.clipboardClient = .fixed(changeCount: matchingChangeCount)
                    $0.userDefaultsClient = .recording(read: matchingChangeCount, writes: recordedWrites)
                }
            )

            await store.send(.detectClipboardURL)
            await store.finish()
        }

        expectNoDifference(recordedWrites.value, [])
    }

    // Proves the write routes through the injected UserDefaultsClient: the injected read differs from
    // the clipboard change count, so the reducer records the new count through the injected setValue.
    @MainActor
    @Test
    func injectedReadMismatchWritesThroughInjectedSetValue() async {
        let recordedWrites = LockIsolated<[Int]>([])
        let clipboardChangeCount = 42
        let injectedReadValue = 7

        await withSeededProcessGlobal(conflicting: 999) {
            let store = TestStore(
                initialState: PresentationFeature.State(),
                reducer: PresentationFeature.init,
                withDependencies: {
                    $0.clipboardClient = .fixed(changeCount: clipboardChangeCount)
                    $0.userDefaultsClient = .recording(read: injectedReadValue, writes: recordedWrites)
                }
            )

            await store.send(.detectClipboardURL)
            await store.finish()
        }

        expectNoDifference(recordedWrites.value, [clipboardChangeCount])
    }
}

private struct GalleryFailureRouteFixture: CustomTestStringConvertible, Sendable {
    let url: String
    let secret: String

    var testDescription: String { url }
}

private extension PresentationFeatureTests {
    // Seeds a conflicting value into the process-global store for the change-count key, runs the body,
    // then restores the store so the test does not pollute others.
    func withSeededProcessGlobal(conflicting value: Int, _ body: () async -> Void) async {
        let key = AppUserDefaults.clipboardChangeCount.rawValue
        let original = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(value, forKey: key)
        await body()
        if let original {
            UserDefaults.standard.set(original, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private extension ClipboardClient {
    static func fixed(changeCount: Int) -> Self {
        .init(
            url: { nil },
            changeCount: { changeCount },
            saveText: { _ in },
            saveImage: { _, _ in },
            saveImageData: { _ in false }
        )
    }
}

private extension UserDefaultsClient {
    static func recording(read: Int?, writes: LockIsolated<[Int]>) -> Self {
        .init(
            getValue: { _ in read },
            setValue: { value, _ in
                if let intValue = value as? Int {
                    writes.withValue { $0.append(intValue) }
                }
            }
        )
    }
}
