import CoreGraphics
import Foundation

/// The space a translation is set in, centered on its lettering and turned with it.
enum LiveTextTextShape: Equatable {
    /// A rectangle this size, such as where the lettering was, which a plate covers.
    case rectangle(CGSize)
    /// The room a balloon has, which narrows toward its outline as the balloon does, so the lines
    /// follow the balloon's shape, as a letterer sets them.
    case balloon(LiveTextBalloonRoom)

    /// `text` set at `fontSize` in the shape, breaking a word only when `breaksWords`; `nil` when the
    /// shape does not hold it.
    func setting(
        of text: String,
        style: LiveTextTextStyle,
        fontSize: Double,
        breaksWords: Bool
    ) -> LiveTextTextSetting? {
        switch self {
        case .rectangle(let size):
            let layout = LiveTextTextLayout(text: text, style: style, fontSize: fontSize, widths: [size.width])
            guard layout.height <= size.height, breaksWords || !layout.breaksWord else {
                return nil
            }
            return LiveTextTextSetting(lineWidths: [size.width], area: size, center: .zero)
        case .balloon(let room):
            return room.setting(of: text, style: style, fontSize: fontSize, breaksWords: breaksWords)
        }
    }
}

/// A translation set in its shape: the width each of its lines is set at, and the area they are
/// centered in.
struct LiveTextTextSetting: Equatable {
    /// The width of each line in turn; lines past the last take it.
    let lineWidths: [Double]
    /// The area the lines are centered in: a rectangle shape whole, so its plate covers the lettering,
    /// or the box around the lines in a balloon.
    let area: CGSize
    /// Where the area centers, across and down from the lettering's center.
    let center: CGPoint
}
