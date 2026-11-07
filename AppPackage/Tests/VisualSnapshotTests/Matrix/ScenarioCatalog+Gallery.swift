// The detail pages, Comments, the Report form and the Reader (19-07).
extension ScenarioCatalog {
    static var gallery: [String: ScenarioFactory] {
        [
            "comments-block-confirmation": .init(
                make: { try TracerScenarios.comments() }, interact: TracerScenarios.chooseBlock
            )
        ]
    }
}
