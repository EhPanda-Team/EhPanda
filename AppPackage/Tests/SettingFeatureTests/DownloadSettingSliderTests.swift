import AppModels
@testable import SettingFeature
import Testing

// The download settings slider steps through whole numbers of concurrent downloads. It binds the
// setting's limit as a `Double`, and a value between two steps writes the nearer one.
@Suite
struct DownloadSettingSliderTests {
    @Test
    func theSliderReadsTheLimit() {
        var setting = Setting()
        setting.downloadThreadLimit = 3

        #expect(setting.downloadThreadLimitSliderValue == 3)
    }

    @Test
    func theSliderWritesTheNearestWholeLimit() {
        var setting = Setting()
        setting.downloadThreadLimitSliderValue = 2.6
        let roundedUp = setting.downloadThreadLimit
        setting.downloadThreadLimitSliderValue = 4.4
        let roundedDown = setting.downloadThreadLimit

        #expect(roundedUp == 3)
        #expect(roundedDown == 4)
    }
}
