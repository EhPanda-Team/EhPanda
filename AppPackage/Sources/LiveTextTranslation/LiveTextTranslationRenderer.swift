import CoreGraphics
import SwiftUI

/// Draws a translated page over its image: every plate and every painted-out lettering first, so no
/// paint covers a neighbor's text, then every translation.
public enum LiveTextTranslationRenderer {
    /// The focus ring's width in view points, half of it outside the plate.
    static let focusLineWidth = 8.0

    /// Draws `page` into `context`, whose `size` the page image fills.
    public static func draw(
        _ page: LiveTextTranslatedPage,
        focusedGroupID: UUID?,
        focusColor: Color,
        in context: GraphicsContext,
        size: CGSize
    ) {
        guard page.pageSize.width > 0, page.pageSize.height > 0 else {
            return
        }
        let pageToView = CGAffineTransform(
            scaleX: size.width / page.pageSize.width,
            y: size.height / page.pageSize.height
        )
        for group in page.groups {
            let plate = Path(roundedRect: group.plate.localBounds, cornerRadius: group.cornerRadius)
                .applying(group.plate.transform.concatenating(pageToView))
            if group.id == focusedGroupID {
                context.stroke(plate, with: .color(focusColor.opacity(0.6)), lineWidth: focusLineWidth)
            }
            switch group.fill {
            case .balloon(let paint, _):
                context.draw(Image(decorative: paint.image, scale: 1), in: paint.rect.applying(pageToView))
            case .background(let color, _):
                context.fill(plate, with: .color(color.color))
            case .plate:
                var shadowed = context
                shadowed.addFilter(.shadow(color: .black.opacity(0.3), radius: group.shadowRadius * pageToView.a))
                shadowed.fill(plate, with: .color(.white))
            }
        }
        context.withCGContext { cgContext in
            for group in page.groups {
                cgContext.saveGState()
                cgContext.concatenate(group.textArea.transform.concatenating(pageToView))
                LiveTextTextLayout(
                    text: group.text,
                    style: LiveTextTextStyle(language: page.language),
                    fontSize: group.fontSize,
                    width: group.lineWidth,
                    color: group.fill.textColor,
                    maximumHeight: group.textArea.size.height
                )
                .draw(centeredIn: group.textArea.localBounds, in: cgContext)
                cgContext.restoreGState()
            }
        }
    }
}

private extension LiveTextColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }
}
