import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "LogsClient", category: category)
    }
}
