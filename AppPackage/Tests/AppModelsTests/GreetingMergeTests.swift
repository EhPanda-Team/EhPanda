import Foundation
import Testing
import AppModels

// REV-21 / #3: greetings have two writers (the Setting daily fetch and the Detail-page parse), so the
// "keep the newer" merge lives on `Optional<Greeting>.mergeNewer`. A stale detail-page greeting must
// not clobber a fresher one. The greeting itself is a session-only in-memory shared slot (`.greeting`),
// so its non-persistence is enforced by the key's strategy rather than a Codable round-trip.
@Suite
struct GreetingMergeTests {
    private let older = Greeting(gainedCredits: 1, updateTime: Date(timeIntervalSince1970: 100))
    private let newer = Greeting(gainedCredits: 2, updateTime: Date(timeIntervalSince1970: 200))

    @Test
    func mergeNewerAdoptsWhenNoneHeld() {
        var greeting: Greeting?
        greeting.mergeNewer(newer)
        #expect(greeting?.gainedCredits == 2)
    }

    @Test
    func mergeNewerAdoptsAStrictlyNewerGreeting() {
        var greeting: Greeting? = older
        greeting.mergeNewer(newer)
        #expect(greeting?.gainedCredits == 2)
    }

    @Test
    func mergeNewerKeepsTheHeldGreetingWhenIncomingIsOlder() {
        var greeting: Greeting? = newer
        greeting.mergeNewer(older)
        #expect(greeting?.gainedCredits == 2)
    }

    @Test
    func mergeNewerIgnoresADatelessGreeting() {
        var greeting: Greeting? = newer
        greeting.mergeNewer(Greeting(gainedCredits: 9, updateTime: nil))
        #expect(greeting?.gainedCredits == 2)
    }
}
