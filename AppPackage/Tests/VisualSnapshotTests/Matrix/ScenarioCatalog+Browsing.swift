// First launch, the shell, Home, Front Page, Popular, Watched, Toplists and History (19-05).
extension ScenarioCatalog {
    static var browsing: [String: ScenarioFactory] {
        [
            "agewall-unticked": .init(make: { TracerScenarios.ageWall() }),
            "home-populated": .init(make: { TracerScenarios.home() }, prepare: TracerScenarios.cacheHomeArtwork)
        ]
    }
}
