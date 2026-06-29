import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "NetworkingFeature", category: category)
    }
}
