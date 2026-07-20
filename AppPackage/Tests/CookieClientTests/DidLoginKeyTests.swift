import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Testing

// Serialized: this suite is deliberately a single sequential test, and the reason is not caution —
// it is a coupling that lives in a third-party library's global state, which no injection at this
// layer can remove.
//
// Sharing keeps its `@SharedReader` references in a process-global weak cache keyed by the key's
// id. `.didLogin` has one constant id, so every reader of it in the process resolves to the *same*
// underlying reference for as long as any one of them is alive — and that reference captured the
// `cookieClient` in scope when it was first created. Two cases reading `@SharedReader(.didLogin)`
// with overlapping lifetimes would therefore both observe whichever case's `CookieClient.testing()`
// jar happened to win the race, regardless of what each one injected via `withDependencies`.
//
// Giving each case its own key id would dissolve the coupling but also the coverage: the point is
// to test the production `.didLogin` key, not a per-test copy of it. So the isolation mechanism is
// the suite's shape — exactly one live reader at a time. A `.serialized` trait would not help; it
// orders cases *within* a suite, and one case needs no ordering.
//
// Both login and logout live in that one case for the same reason. They also have to stay in this
// order: the reader must observe the jar filling before `clearAll` empties it, which is the same
// ordering the production child-logout reload must never race against.
struct DidLoginKeyTests {
    @Test
    func tracksJarChangesAcrossLoginAndLogout() async throws {
        let client = CookieClient.testing()
        try await withDependencies {
            $0.cookieClient = client
        } operation: {
            @SharedReader(.didLogin) var didLogin: Bool
            #expect(didLogin == false)

            client.setOrEditCookie(for: GalleryHost.ehentai.url, key: "ipb_member_id", value: "member-fixture")
            client.setOrEditCookie(for: GalleryHost.ehentai.url, key: "ipb_pass_hash", value: "pass-fixture")
            try await pollUntil { didLogin }
            #expect(didLogin)

            client.clearAll()
            try await pollUntil { !didLogin }
            #expect(didLogin == false)
        }
    }
}

// The key's subscriber yields on its own task, so the reader updates asynchronously; bounded so a
// regression fails after ~1s instead of hanging.
private func pollUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<100 where !condition() {
        try await Task.sleep(for: .milliseconds(10))
    }
}
