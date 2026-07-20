import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
import Testing

struct DidLoginKeyTests {
    @Test
    func loadsLoggedOutStateAndTracksLogin() async throws {
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
        }
    }

    @Test
    func loadsLoggedInStateAndTracksLogout() async throws {
        let client = CookieClient.testing(memberID: "member-fixture", passHash: "pass-fixture")
        try await withDependencies {
            $0.cookieClient = client
        } operation: {
            @SharedReader(.didLogin) var didLogin: Bool
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
