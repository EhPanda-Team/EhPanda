@testable import AppModels
import Testing

struct GreetingContentTests {
    @Test
    func twoRewardsJoinWithAnd() {
        let greeting = Greeting(gainedEXP: 10, gainedCredits: 500)

        #expect(greeting.gainContent == "You gain 10 EXP and 500 Credits!")
    }

    @Test
    func manyRewardsJoinTheLastWithAnd() {
        let greeting = Greeting(gainedEXP: 10, gainedCredits: 500, gainedGP: 200, gainedHath: 1)

        #expect(greeting.gainContent == "You gain 10 EXP, 500 Credits, 200 GP and 1 Hath!")
    }

    @Test
    func aSingleRewardStandsAlone() {
        let greeting = Greeting(gainedHath: 1)

        #expect(greeting.gainContent == "You gain 1 Hath!")
    }

    @Test
    func noRewardsHaveNoContent() {
        #expect(Greeting().gainContent == nil)
    }
}
