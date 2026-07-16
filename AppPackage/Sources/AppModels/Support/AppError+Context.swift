import Foundation

/// A type-erased value that preserves both `Hashable` and `Sendable` semantics.
public struct AnyHashableBox: Hashable, Sendable {
    public let base: any Hashable & Sendable

    @_disfavoredOverload
    public init(_ base: any Hashable & Sendable) {
        self.init(base)
    }

    public init(_ base: some Hashable & Sendable) {
        if let base = base as? Self {
            self = base
        } else {
            self.base = base
        }
    }

    public var displayValue: String {
        String(describing: base)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(base))
    }
}

extension AnyHashableBox: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnyHashableBox: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyHashableBox: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyHashableBox: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

public typealias Context = [ContextKey: AnyHashableBox]

extension Dictionary where Key == ContextKey, Value == AnyHashableBox {
    /// Builds user-visible gallery diagnostics without retaining access-bearing route components.
    public static func galleryFailure(url: URL, action: String, reason: String) -> Self {
        let pathComponents = url.pathComponents
        let candidate: String?
        if pathComponents.count >= 3, pathComponents[1] == "g" {
            candidate = pathComponents[2]
        } else if pathComponents.count >= 4, pathComponents[1] == "s" {
            candidate = pathComponents[3].split(separator: "-", maxSplits: 1).first.map(String.init)
        } else {
            candidate = nil
        }

        var context: Self = [
            .action: AnyHashableBox(action),
            .reason: AnyHashableBox(reason)
        ]
        if let candidate,
           candidate.isEmpty == false,
           candidate.utf8.allSatisfy({ (48...57).contains($0) }),
           let galleryID = Int(candidate) {
            context[.gid] = AnyHashableBox(galleryID)
        }
        return context
    }
}

/// User-visible diagnostic labels. Gallery diagnostics use ``Dictionary/galleryFailure(url:action:reason:)``
/// so access-bearing route components never enter their context.
public enum ContextKey: String, Hashable, Sendable {
    case action = "Action"
    case reason = "Reason"
    case url = "URL"
    case statusCode = "Status Code"
    case gid = "Gallery ID"
}

/// A surfaced error and its per-incident diagnostic context.
///
/// Context belongs on this companion instead of ``AppError`` so the error enum's established cases and
/// pattern-matching behavior remain unchanged.
public struct ErrorInfo: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let error: AppError
    public let context: Context?

    public init(error: AppError, context: Context? = nil) {
        self.id = UUID()
        self.error = error
        self.context = context
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.error == rhs.error && lhs.context == rhs.context
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(error)
        hasher.combine(context)
    }
}
