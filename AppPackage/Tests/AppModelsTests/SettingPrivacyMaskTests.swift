import Testing
import AppModels

struct SettingPrivacyMaskTests {
    @Test
    func defaultIntensityIsTen() {
        #expect(Setting().privacyMaskIntensity == 10)
    }

    @Test
    func intensityCanBeDisabledIndependently() {
        var setting = Setting()

        setting.privacyMaskIntensity = 0

        #expect(setting.privacyMaskIntensity == 0)
    }
}
