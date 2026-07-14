import Foundation
import AppTools
import ComposableArchitecture
import CustomDump
import Testing
@testable import ClipboardClient
@testable import UserDefaultsClient
@testable import AppFeature

@MainActor
struct AppRouteReducerTests {
    // Proves the read routes through the injected UserDefaultsClient, not UserDefaults.standard:
    // the injected read equals the clipboard change count, so the guard short-circuits and no write
    // occurs — even though the process-global holds a conflicting value that would force a write if
    // it were consulted.
    @Test
    func injectedReadSuppressesWriteDespiteConflictingProcessGlobal() async {
        let recordedWrites = LockIsolated<[Int]>([])
        let matchingChangeCount = 42

        await withSeededProcessGlobal(conflicting: 999) {
            let store = TestStore(
                initialState: AppRouteReducer.State(),
                reducer: AppRouteReducer.init,
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
    @Test
    func injectedReadMismatchWritesThroughInjectedSetValue() async {
        let recordedWrites = LockIsolated<[Int]>([])
        let clipboardChangeCount = 42
        let injectedReadValue = 7

        await withSeededProcessGlobal(conflicting: 999) {
            let store = TestStore(
                initialState: AppRouteReducer.State(),
                reducer: AppRouteReducer.init,
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

private extension AppRouteReducerTests {
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
