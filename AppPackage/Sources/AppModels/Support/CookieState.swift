public struct CookiesState: Equatable, Sendable {
    public static func empty(_ host: GalleryHost) -> Self {
        .init(
            host: host,
            igneous: .empty,
            memberID: .empty,
            passHash: .empty
        )
    }
    public var allCases: [CookieState] {[
        igneous, memberID, passHash
    ]}

    public let host: GalleryHost
    public var igneous: CookieState
    public var memberID: CookieState
    public var passHash: CookieState

    public init(
        host: GalleryHost,
        igneous: CookieState,
        memberID: CookieState,
        passHash: CookieState
    ) {
        self.host = host
        self.igneous = igneous
        self.memberID = memberID
        self.passHash = passHash
    }
}

public struct CookieState: Equatable, Sendable {
    public static let empty: Self = .init(
        key: "", value: .init(
            rawValue: "", localizedString: ""
        )
    )

    public let key: String
    public var value: CookieValue
    public var editingText = ""

    public init(key: String, value: CookieValue, editingText: String = "") {
        self.key = key
        self.value = value
        self.editingText = editingText
    }
}
