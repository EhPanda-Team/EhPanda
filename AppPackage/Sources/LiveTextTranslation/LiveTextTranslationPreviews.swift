#if DEBUG
import AppModels
import SwiftUI
import UIKit

/// A comic page drawn for previews: speech balloons with lettering, a caption box and a line over
/// busy art, with the groups Live Text would recognize on it and their translations.
private struct PreviewPage {
    struct Lettering {
        let lines: [String]
        let origin: CGPoint
        let lineHeight: Double
        let degrees: Double
    }

    static let size = CGSize(width: 1000, height: 1400)

    let image: CGImage
    let groups: [LiveTextGroup]
    let translations: [UUID: String]
    let sources: [UUID: String]

    /// The page with `letterings`, each translated by the translation at its position.
    init?(letterings: [Lettering], translations: [String]) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: Self.size, format: format).image { context in
            Self.drawArt(in: context.cgContext)
            for lettering in letterings {
                Self.draw(lettering, in: context.cgContext)
            }
        }
        guard let image = rendered.cgImage else {
            return nil
        }
        var groups = [LiveTextGroup]()
        var translationsByGroup = [UUID: String]()
        var sources = [UUID: String]()
        for (lettering, translation) in zip(letterings, translations) {
            guard let group = LiveTextGroup(blocks: Self.blocks(of: lettering)) else {
                continue
            }
            groups.append(group)
            translationsByGroup[group.id] = translation
            sources[group.id] = lettering.lines.joined(separator: " ")
        }
        self.image = image
        self.groups = groups
        self.translations = translationsByGroup
        self.sources = sources
    }

    private static func drawArt(in context: CGContext) {
        context.setFillColor(UIColor(white: 0.93, alpha: 1).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        for stripe in 0..<40 {
            let hue = Double(stripe % 7) / 7
            context.setFillColor(UIColor(hue: hue, saturation: 0.5, brightness: 0.8, alpha: 1).cgColor)
            context.fill(CGRect(x: Double(stripe) * 25, y: 1050, width: 25, height: 350))
        }
        context.setFillColor(UIColor.white.cgColor)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(5)
        let balloons = [CGRect(x: 80, y: 80, width: 520, height: 300), CGRect(x: 520, y: 430, width: 420, height: 330)]
        for balloon in balloons {
            context.fillEllipse(in: balloon)
            context.strokeEllipse(in: balloon)
        }
        context.setFillColor(UIColor(red: 1, green: 0.93, blue: 0.6, alpha: 1).cgColor)
        context.fill(CGRect(x: 60, y: 820, width: 560, height: 150))
    }

    private static func draw(_ lettering: Lettering, in context: CGContext) {
        let font = UIFont.systemFont(ofSize: lettering.lineHeight * 0.8, weight: .bold)
        context.saveGState()
        context.translateBy(x: lettering.origin.x, y: lettering.origin.y)
        context.rotate(by: lettering.degrees * .pi / 180)
        for (number, line) in lettering.lines.enumerated() {
            NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: UIColor.black])
                .draw(at: CGPoint(x: 0, y: Double(number) * lettering.lineHeight))
        }
        context.restoreGState()
    }

    /// Each line's bounds as Vision reports them, normalized with the origin at the top left.
    private static func blocks(of lettering: Lettering) -> [LiveTextBlock] {
        let font = UIFont.systemFont(ofSize: lettering.lineHeight * 0.8, weight: .bold)
        let angle = lettering.degrees * .pi / 180
        func point(_ across: Double, _ down: Double) -> CGPoint {
            CGPoint(
                x: (lettering.origin.x + across * cos(angle) - down * sin(angle)) / size.width,
                y: (lettering.origin.y + across * sin(angle) + down * cos(angle)) / size.height
            )
        }
        return lettering.lines.enumerated().map { number, line in
            let width = NSAttributedString(string: line, attributes: [.font: font]).size().width
            let top = Double(number) * lettering.lineHeight
            return LiveTextBlock(
                text: line,
                bounds: LiveTextBounds(
                    topLeft: point(0, top),
                    topRight: point(width, top),
                    bottomLeft: point(0, top + lettering.lineHeight),
                    bottomRight: point(width, top + lettering.lineHeight)
                )
            )
        }
    }
}

private struct PreviewTranslatedPage: View {
    let page: PreviewPage?
    let language: Locale.Language

    var body: some View {
        if let page {
            let translated = LiveTextTranslatedPage.layOut(
                groups: page.groups,
                sources: page.sources,
                translations: page.translations,
                language: language,
                image: page.image
            )
            Image(decorative: page.image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                    Canvas { context, size in
                        LiveTextTranslationRenderer.draw(
                            translated,
                            focusedGroupID: nil,
                            focusColor: .accentColor,
                            in: context,
                            size: size
                        )
                    }
                }
        }
    }
}

/// English lettering, each to be given its translation.
private let englishLetterings = [
    PreviewPage.Lettering(
        lines: ["WHERE DO YOU THINK", "YOU'RE GOING?"],
        origin: CGPoint(x: 170, y: 170),
        lineHeight: 48,
        degrees: 0
    ),
    PreviewPage.Lettering(
        lines: ["I TOLD YOU TO", "STAY HERE!"],
        origin: CGPoint(x: 600, y: 540),
        lineHeight: 48,
        degrees: -6
    ),
    PreviewPage.Lettering(
        lines: ["MEANWHILE, AT THE", "OLD STATION..."],
        origin: CGPoint(x: 90, y: 850),
        lineHeight: 48,
        degrees: 0
    ),
    PreviewPage.Lettering(lines: ["WAIT!"], origin: CGPoint(x: 400, y: 1180), lineHeight: 48, degrees: 12)
]

/// The same lettering in Japanese, set across.
private let japaneseLetterings = [
    PreviewPage.Lettering(lines: ["どこに行くと", "思ってるの？"], origin: CGPoint(x: 200, y: 170), lineHeight: 48, degrees: 0),
    PreviewPage.Lettering(
        lines: ["ここにいてって", "言ったでしょ！"],
        origin: CGPoint(x: 600, y: 540),
        lineHeight: 48,
        degrees: -6
    ),
    PreviewPage.Lettering(lines: ["その頃、", "古い駅では…"], origin: CGPoint(x: 90, y: 850), lineHeight: 48, degrees: 0),
    PreviewPage.Lettering(lines: ["待って！"], origin: CGPoint(x: 400, y: 1180), lineHeight: 48, degrees: 12)
]

private func previewPage(_ translations: [String]) -> PreviewPage? {
    PreviewPage(letterings: englishLetterings, translations: translations)
}

#Preview("English to Japanese") {
    PreviewTranslatedPage(
        page: previewPage(["どこに行くと思ってるの？", "ここにいてって言ったでしょ！", "その頃、古い駅では…", "待って！"]),
        language: .init(identifier: "ja")
    )
}

#Preview("English to German") {
    PreviewTranslatedPage(
        page: previewPage([
            "Wohin denkst du, gehst du?",
            "Ich habe dir gesagt, du sollst hierbleiben!",
            "Währenddessen am alten Bahnhof …",
            "Warte!"
        ]),
        language: .init(identifier: "de")
    )
}

#Preview("Japanese to English") {
    PreviewTranslatedPage(
        page: PreviewPage(
            letterings: japaneseLetterings,
            translations: [
                "Where do you think you're going?",
                "I told you to stay here!",
                "Meanwhile, at the old station...",
                "Wait!"
            ]
        ),
        language: .init(identifier: "en")
    )
}

#Preview("English to Traditional Chinese") {
    PreviewTranslatedPage(
        page: previewPage(["你以為你要去哪裡？", "我叫你待在這裡！", "與此同時，在舊車站……", "等等！"]),
        language: .init(identifier: "zh-Hant")
    )
}
#endif
