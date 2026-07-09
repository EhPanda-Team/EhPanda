import Testing
import AppModels

// V2-B / #9: `maximumScaleFactor` and `doubleTapScaleFactor` are mutually clamped in the `Setting`
// model itself, so `doubleTapScaleFactor <= maximumScaleFactor` holds on every write path. The reader
// sheet writes these through a direct `@Shared(.setting)` binding that never passes through a reducer,
// so the invariant can no longer live in a `BindingReducer`; this pins it at the model level.
@Suite
struct SettingScaleClampTests {
    @Test
    func loweringMaximumClampsDoubleTapDown() {
        var setting = Setting()
        setting.doubleTapScaleFactor = 3
        setting.maximumScaleFactor = 2
        #expect(setting.doubleTapScaleFactor == 2)
        #expect(setting.maximumScaleFactor == 2)
    }

    @Test
    func raisingDoubleTapPushesMaximumUp() {
        var setting = Setting()
        setting.doubleTapScaleFactor = 5
        #expect(setting.maximumScaleFactor == 5)
        #expect(setting.doubleTapScaleFactor == 5)
    }

    @Test
    func consistentValuesAreLeftUntouched() {
        var setting = Setting()
        setting.maximumScaleFactor = 4
        #expect(setting.maximumScaleFactor == 4)
        #expect(setting.doubleTapScaleFactor == 2)
    }
}
