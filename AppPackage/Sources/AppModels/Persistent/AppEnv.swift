public struct AppEnv: Codable, Equatable, Sendable {
    public init(
        user: User,
        setting: Setting,
        searchFilter: Filter,
        globalFilter: Filter,
        watchedFilter: Filter,
        tagTranslator: TagTranslator,
        historyKeywords: [String],
        quickSearchWords: [QuickSearchWord]
    ) {
        self.user = user
        self.setting = setting
        self.searchFilter = searchFilter
        self.globalFilter = globalFilter
        self.watchedFilter = watchedFilter
        self.tagTranslator = tagTranslator
        self.historyKeywords = historyKeywords
        self.quickSearchWords = quickSearchWords
    }
    public let user: User
    public let setting: Setting
    public let searchFilter: Filter
    public let globalFilter: Filter
    public let watchedFilter: Filter
    public let tagTranslator: TagTranslator
    public let historyKeywords: [String]
    public let quickSearchWords: [QuickSearchWord]
}

extension AppEnv: CustomStringConvertible {
    public var description: String {
        let params = String(
            describing: [
                "user": user,
                "setting": setting,
                "tagTranslator": tagTranslator,
                "historyKeywordsCount": historyKeywords.count,
                "quickSearchWordsCount": quickSearchWords.count
            ]
            as [String: Any]
        )
        return "AppEnv(\(params))"
    }
}
