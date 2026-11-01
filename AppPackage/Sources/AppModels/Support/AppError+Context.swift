public import Foundation

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
        // Drops the leading "/" to reach <kind>/<gid>/<token>: a gallery route carries the id in the
        // second slot, while a single-page route carries it as the "<gid>-<page>" token in the third.
        var route = url.pathComponents.dropFirst()
        let candidate: String? = switch route.popFirst() {
        case "g"?: route.first
        case "s"?: route.dropFirst().first?.split(separator: "-", maxSplits: 1).first.map(String.init)
        default: nil
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

    /// Builds diagnostics for an unsupported link without retaining access-bearing URL components.
    public static func unsupportedLink(url: URL) -> Self {
        [
            .action: AnyHashableBox(String(localized: .errorContextOpenLink)),
            .reason: AnyHashableBox(String(localized: .errorContextUnrecognizedLink)),
            .link: AnyHashableBox(sanitizedUnsupportedLink(url))
        ]
    }

    private static func sanitizedUnsupportedLink(_ url: URL) -> String {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = source.scheme,
              let host = source.host else {
            return String(localized: .appErrorUnsupportedDeepLink)
        }

        var sanitized = URLComponents()
        sanitized.scheme = scheme
        sanitized.host = host

        let pathComponents = source.path.split(separator: "/", omittingEmptySubsequences: true)
        if let firstPathComponent = pathComponents.first {
            sanitized.path = "/\(firstPathComponent)"
        }

        guard let rendering = sanitized.string else {
            return String(localized: .appErrorUnsupportedDeepLink)
        }
        return pathComponents.count > 1 ? rendering + "/…" : rendering
    }
}

/// User-visible diagnostic rows. This fixed whitelist deliberately has no raw URL slot: gallery diagnostics
/// retain only a validated numeric identifier, while unsupported-link diagnostics retain a sanitized rendering.
/// The raw value only keeps the rows in the same order in every language; ``label`` is what the user reads.
public enum ContextKey: String, Hashable, Sendable {
    case action = "Action"
    case reason = "Reason"
    case statusCode = "Status Code"
    case gid = "Gallery ID"
    case link = "Link"

    public var label: LocalizedStringResource {
        switch self {
        case .action: .errorContextAction
        case .reason: .errorContextReason
        case .statusCode: .errorContextStatusCode
        case .gid: .errorContextGalleryId
        case .link: .errorContextLink
        }
    }
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
