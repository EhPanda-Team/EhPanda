import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "AppFeature", category: category)
    }
}
