/// The colour the site draws the signed-in user's own rating in, named by the star class it puts on the rating
/// (`irr`, `irg`, `irb`). A gallery the user has not rated has none and its stars are the plain average.
public enum UserRatingTint: String, Codable, Equatable, Sendable {
    case red
    case green
    case blue
}
