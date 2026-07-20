import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Testing

struct DidLoginKeyTests {
    // A single sequential test on purpose: Sharing's reference cache is a process-wide weak table
    // keyed by the key's constant id, so two parallel tests whose readers are alive at the same
    // time would share the first test's captured client. One reader, one client, no cross-wiring.
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
