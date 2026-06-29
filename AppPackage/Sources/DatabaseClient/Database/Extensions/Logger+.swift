import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "DatabaseClient", category: category)
    }
}
