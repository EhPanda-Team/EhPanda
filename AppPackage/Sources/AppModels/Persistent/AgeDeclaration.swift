/// The age wall's declaration, versioned by its wording (DD-08).
///
/// `Setting.ageDeclarationVersion` stores the version the user confirmed. Changing the approved
/// sentence means a new version, which asks every user again (D-05).
public enum AgeDeclaration {
    /// The wording version of the declaration this build shows.
    public static let currentVersion = 1

    /// Whether a stored version confirms the declaration this build shows.
    ///
    /// Only equality counts. A stored version from older wording, or from a newer build after a
    /// downgrade, asks again rather than skipping the wall (P-10).
    public static func isConfirmed(_ version: Int?) -> Bool {
        version == currentVersion
    }
}
