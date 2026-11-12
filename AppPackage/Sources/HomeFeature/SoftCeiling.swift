import Foundation

/// Compresses values above a knee smoothly onto a ceiling, keeping their order.
///
/// Values at or below the knee pass through unchanged. Above it, a power curve leaves the knee with
/// the identity's slope and reaches the ceiling exactly at `domain`, the largest value the input
/// takes, so a value that crosses the knee during ColorfulX's color transition shows no kink.
struct SoftCeiling {
    let knee: Double
    let ceiling: Double
    let domain: Double

    func callAsFunction(_ value: Double) -> Double {
        guard value > knee else { return value }
        let progress = min((value - knee) / (domain - knee), 1)
        let exponent = (domain - knee) / (ceiling - knee)
        return knee + (ceiling - knee) * (1 - pow(1 - progress, exponent))
    }
}
