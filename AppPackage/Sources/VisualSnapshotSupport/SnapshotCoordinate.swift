public import Foundation

/// One picture of the Phase 19 matrix (19-CONTEXT D-04): a scenario in one language, text size, orientation, device
/// family and appearance.
///
/// The key and the baseline path are a contract shared with the Python tools (`Scripts/visual/snapshot_matrix.py`)
/// and the snapshot repository layout (19-RESEARCH §6, §9); both sides test the same sample strings.
public struct SnapshotCoordinate: Hashable, Codable, Sendable {
    public static let locales = ["en", "de", "ja", "ko", "zh-Hans", "zh-Hant"]
    public static let sizes = ["xSmall", "large", "accessibility5"]
    public static let orientations = ["portrait", "landscape"]
    public static let families = ["iphone", "ipad"]
    public static let themes = ["light", "dark"]

    public let scenario: String
    public let locale: String
    public let size: String
    public let orientation: String
    public let family: String
    public let theme: String

    public init(scenario: String, locale: String, size: String, orientation: String, family: String, theme: String) {
        self.scenario = scenario
        self.locale = locale
        self.size = size
        self.orientation = orientation
        self.family = family
        self.theme = theme
    }

    /// `scenario__locale__size__orientation__family__theme`.
    public var key: String {
        [scenario, locale, size, orientation, family, theme].joined(separator: "__")
    }

    /// `<family>/<locale>/<size>/<scenario>/<orientation>-<theme>.png`, relative to a baseline slice root.
    public var baselinePath: String {
        "\(family)/\(locale)/\(size)/\(scenario)/\(orientation)-\(theme).png"
    }

    /// The configuration name of the test plan that carries this coordinate's language and text size.
    public var configuration: String {
        "\(locale)-\(size)"
    }
}
