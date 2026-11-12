import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "BackgroundProcessingClient", category: category)
    }
}
