import AppModels
import Resources

extension GalleryDetail {
    /// Returns the localized binary unit. The numeric argument only selects the plural form;
    /// each catalog variant contains the unit word alone so VoiceOver does not repeat the number.
    func accessibilitySizeUnit(quantity: Double) -> String? {
        switch sizeType {
        case "KiB": String(localized: .accessibilitySizeKibibyte(quantity: Float(quantity)))
        case "MiB": String(localized: .accessibilitySizeMebibyte(quantity: Float(quantity)))
        case "GiB": String(localized: .accessibilitySizeGibibyte(quantity: Float(quantity)))
        default: nil
        }
    }
}
