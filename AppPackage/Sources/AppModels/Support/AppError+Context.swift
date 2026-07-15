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

/// User-visible diagnostic labels. This fixed whitelist deliberately carries no secrets: URL values
/// are path-only, and cookies, tokens, passwords, credentials, IP addresses, and home paths are never context.
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
