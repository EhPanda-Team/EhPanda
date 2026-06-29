import OSLog
import Foundation

private let logger = Logger(category: "ForceUnwrap")

extension Optional {
    public var forceUnwrapped: Wrapped! {
        if let value = self {
            return value
        }
        logger.error("Failed in force unwrapping type: \(String(describing: Wrapped.self), privacy: .public)")
        return nil
    }
}
