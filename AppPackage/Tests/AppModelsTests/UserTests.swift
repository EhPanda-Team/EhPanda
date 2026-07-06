import Foundation
import Testing
import AppModels

// REV-21: greetings have two writers (the Setting daily fetch and the Detail-page parse), so the
// "keep the newer" merge lives on `User.mergeGreeting`. A stale detail-page greeting must not clobber
// a fresher one. Greeting is also session-only: it must never survive a Codable round-trip.
@Suite
struct UserTests {
    private let older = Greeting(gainedCredits: 1, updateTime: Date(timeIntervalSince1970: 100))
    private let newer = Greeting(gainedCredits: 2, updateTime: Date(timeIntervalSince1970: 200))

    @Test
    func mergeGreetingAdoptsWhenNoneHeld() {
        var user = User()
        user.mergeGreeting(newer)
        #expect(user.greeting?.gainedCredits == 2)
    }

    @Test
    func mergeGreetingAdoptsAStrictlyNewerGreeting() {
        var user = User()
        user.greeting = older
        user.mergeGreeting(newer)
        #expect(user.greeting?.gainedCredits == 2)
    }

    @Test
    func mergeGreetingKeepsTheHeldGreetingWhenIncomingIsOlder() {
        var user = User()
        user.greeting = newer
        user.mergeGreeting(older)
        #expect(user.greeting?.gainedCredits == 2)
    }

    @Test
    func mergeGreetingIgnoresADatelessGreeting() {
        var user = User()
        user.greeting = newer
        user.mergeGreeting(Greeting(gainedCredits: 9, updateTime: nil))
        #expect(user.greeting?.gainedCredits == 2)
    }

    @Test
    func greetingIsNeverPersistedThroughCodable() throws {
        var user = User(displayName: "keep-me", credits: "42")
        user.greeting = newer

        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(User.self, from: data)

        #expect(decoded.greeting == nil)          // session-only: dropped on encode/decode
        #expect(decoded.displayName == "keep-me") // durable fields survive
        #expect(decoded.credits == "42")
    }
}
