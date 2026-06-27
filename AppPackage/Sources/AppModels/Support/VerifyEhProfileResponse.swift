public struct VerifyEhProfileResponse: Equatable, Sendable {
    public let profileValue: Int?
    public let isProfileNotFound: Bool

    public init(profileValue: Int?, isProfileNotFound: Bool) {
        self.profileValue = profileValue
        self.isProfileNotFound = isProfileNotFound
    }
}
