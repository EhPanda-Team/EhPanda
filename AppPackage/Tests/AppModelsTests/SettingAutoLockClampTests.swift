import Testing
import AppModels

// The auto-lock policy and background-blur radius are coupled on the `Setting` model: auto-lock relies
// on a non-zero blur to obscure content, so enabling auto-lock while blur is 0 restores a default blur,
// and dropping blur to 0 disables auto-lock. Kept on the model (not a reducer `BindingReducer`) so every
// write path holds the invariant; this pins that coupling.
@Suite
struct SettingAutoLockClampTests {
    @Test
    func enablingAutoLockWithZeroBlurRestoresBlur() {
        var setting = Setting()
        setting.backgroundBlurRadius = 0
        setting.autoLockPolicy = .instantly
        #expect(setting.backgroundBlurRadius == 10)
        #expect(setting.autoLockPolicy == .instantly)
    }

    @Test
    func zeroingBlurWhileAutoLockOnDisablesAutoLock() {
        var setting = Setting()
        setting.autoLockPolicy = .min1
        setting.backgroundBlurRadius = 0
        #expect(setting.autoLockPolicy == .never)
        #expect(setting.backgroundBlurRadius == 0)
    }

    @Test
    func zeroingBlurWhileAutoLockNeverIsLeftUntouched() {
        var setting = Setting()
        setting.backgroundBlurRadius = 0
        #expect(setting.backgroundBlurRadius == 0)
        #expect(setting.autoLockPolicy == .never)
    }
}
