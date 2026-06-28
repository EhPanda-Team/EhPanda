import Foundation
import SwiftyBeaverExt

extension Optional {
    public var forceUnwrapped: Wrapped! {
        if let value = self {
            return value
        }
        Logger.error(
            "Failed in force unwrapping...",
            context: ["type": Wrapped.self]
        )
        return nil
    }
}
