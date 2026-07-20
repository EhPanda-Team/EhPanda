import AppTools
@_exported import OSLog

public extension Logger {
    init(moduleName: String, category: String) {
        self.init(
            subsystem: [Defaults.App.identifier, moduleName].joined(separator: "."),
            category: category
        )
    }
}
