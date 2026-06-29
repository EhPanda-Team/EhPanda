import OSLogExt

extension Logger {
    init(category: String) {
        self.init(moduleName: "DownloadClient", category: category)
    }
}
