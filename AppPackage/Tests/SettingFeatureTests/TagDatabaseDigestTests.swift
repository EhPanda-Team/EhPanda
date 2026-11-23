import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import Testing
import TestingSupport

@Suite(.isolatedAppStorage)
struct TagDatabaseDigestTests {
    /// The metadata survives a purged cache, so comparing it would keep the table empty until the next
    /// change to this language, which for some languages can be weeks away.
    @Test
    func updateCheckComparesTheLoadedTableNotTheMetadata() {
        withDependencies {
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            let state = SettingReducer.State()
            state.$tagTranslatorInfo.withLock({ $0 = TagTranslatorInfo(language: .english, digest: "sha256:cached") })
            #expect(state.loadedTagDatabaseDigest == nil)

            state.$tagTranslator.withLock({ $0 = TagTranslator(language: .english, digest: "sha256:cached") })
            #expect(state.loadedTagDatabaseDigest == "sha256:cached")
        }
    }
}
