import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "AppModels", category: category)
    }
}
