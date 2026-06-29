import OSLog

// AppTools cannot import OSLogExt (OSLogExt depends on AppTools), so it composes
// the subsystem locally instead of using OSLogExt's `Logger(moduleName:category:)`.
extension Logger {
    init(category: String) {
        self.init(
            subsystem: [Defaults.App.identifier, "AppTools"].joined(separator: "."),
            category: category
        )
    }
}

let logger = Logger(category: "ForceUnwrap")
