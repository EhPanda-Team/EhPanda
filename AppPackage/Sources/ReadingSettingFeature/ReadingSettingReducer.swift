public import AppModels
public import ComposableArchitecture
public import Sharing

// A state-only reducer for the reading-setting editor. It carries `@Shared(.setting)` and vends the
// shared projection (`sharedSetting`) so `ReadingSettingView` binds through its own store instead of
// holding a `@Shared` itself. It runs no logic: every field write goes straight through the shared
// value, and the `Setting` model's clamps keep those writes consistent. Any orientation side effect
// stays with the host — the reader drives it from `ReadingReducer`; the Setting tab has none. The reader
// also tells it whether the open gallery is a webtoon (`galleryIsWebtoon`), which locks the direction
// picker while the user reads webtoons vertically (D-03); the Setting tab, with no gallery open, never does.
@Reducer
public struct ReadingSettingReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.setting) public var setting: Setting
        /// Whether the gallery open in the reader is a webtoon. The reader sets it as it presents the editor and
        /// keeps it current while the editor is open, should the verdict land then.
        public var galleryIsWebtoon: Bool
        public var sharedSetting: Shared<Setting> { $setting }

        /// Whether the direction picker is locked: the open gallery is read vertically whatever it says (D-02,
        /// D-03). Turning "always read webtoons vertically" off here lifts the lock at once.
        public var locksDirection: Bool {
            setting.forcesVerticalReading(galleryIsWebtoon: galleryIsWebtoon)
        }

        public init(galleryIsWebtoon: Bool = false) {
            self.galleryIsWebtoon = galleryIsWebtoon
        }
    }

    public enum Action: Equatable, Sendable {}

    public init() {}

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
