public struct CookieValue: Equatable, Sendable {
    public static let empty: Self = .init(
        rawValue: .init(), localizedString: .init()
    )

    public let rawValue: String
    public let localizedString: String

    public init(rawValue: String, localizedString: String) {
        self.rawValue = rawValue
        self.localizedString = localizedString
    }

    public var isInvalid: Bool {
        !localizedString.isEmpty && !rawValue.isEmpty
    }
    public var placeholder: String {
        localizedString.isEmpty ? rawValue : localizedString
    }
}
