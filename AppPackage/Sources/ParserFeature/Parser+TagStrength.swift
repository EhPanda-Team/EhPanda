import AppModels

extension Parser {
    static func tagVoteStrength(cssClasses: String?) -> GalleryTag.VoteStrength? {
        let classes = Set((cssClasses ?? "").split(whereSeparator: \.isWhitespace))
        if classes.contains("gtw") { return .weak }
        if classes.contains("gtl") { return .active }
        if classes.contains("gt") { return .strong }
        return nil
    }
}
