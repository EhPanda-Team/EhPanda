import CoreGraphics
import SFSafeSymbols
import SwiftUI
import Testing
import UIKit

// G-11-8 parity lock. Commit 6dd51b00 rewrote the gallery cells' page-count indicator from a
// hand-composed `HStack { Image; Text }` into a `Label`, and the glyph grew.
//
// The growth only happens INSIDE A LIST. Free-standing, a `Label`'s icon renders at exactly the
// bare `Image`'s size (both 20x16 at `.footnote`); it is the list row's label treatment that
// inflates the icon — measured here at 21.0x17.25 against the pre-sweep 16.25x13.25, roughly 29%
// wider. Both gallery cells and the torrent stat row live in list rows (the masonry grid is one
// eager `List` row), so all six converted sites inflate. Re-asserting `.medium` on the `Image`
// inside the icon closure overrides that ambient inflation and lands back on the baseline; the
// repo's usual `.small` precedent undershoots it by ~20%, which is why the value is measured here
// rather than assumed.
//
// These cases compare rendered forms against EACH OTHER rather than against hardcoded pixel
// constants, so they survive a font-metric change but still fire if a future OS alters how a list
// sizes label icons — exactly when the six call sites would need re-tuning. The production sites
// are pinned to one shared value by the plan's grep gate; this suite pins that value to pre-sweep
// appearance parity.
@MainActor
@Suite
struct PageCountIconScaleTests {
    /// The scale the six corrected call sites apply inside their label icon closures.
    private static let pageCountIconScale: Image.Scale = .medium

    private static let symbol: SFSymbol = .photoOnRectangleAngled
    private static let count = "1234"

    /// The pre-6dd51b00 form, and the appearance target.
    private static var baseline: some View {
        HStack(spacing: 2) {
            Image(systemSymbol: symbol)
            Text(verbatim: count)
        }
    }

    /// The regressed form: a `Label` whose icon carries no explicit scale.
    private static var unscaledLabel: some View {
        Label(count, systemSymbol: symbol)
            .labelIconToTitleSpacing(2)
    }

    /// The corrected form used by the six production call sites.
    private static func scaledLabel(_ scale: Image.Scale) -> some View {
        Label {
            Text(verbatim: count)
        } icon: {
            Image(systemSymbol: symbol)
                .imageScale(scale)
        }
        .labelIconToTitleSpacing(2)
    }

    /// Each candidate sits directly beneath a fresh baseline row, so every comparison is adjacent
    /// and the repeated baseline doubles as a self-check that measurement is stable.
    private static var comparisonList: some View {
        List {
            baseline
            unscaledLabel
            baseline
            scaledLabel(pageCountIconScale)
        }
        .frame(width: listBounds.width, height: listBounds.height)
    }

    private static let listBounds = CGRect(x: 0, y: 0, width: 220, height: 300)

    /// `ImageRenderer` cannot rasterize a `List` — it draws an unsupported-content placeholder — so
    /// list-context renders go through a real hosting controller in a window, then a layer render.
    /// The window is required: a hosting controller whose view is never in a window lays the list
    /// out but never commits a layer tree, and the render comes back blank.
    private static func snapshotImage(_ view: some View) -> UIImage {
        let controller = UIHostingController(rootView: view.font(.footnote))
        let window = UIWindow()
        window.frame = listBounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 8
        return UIGraphicsImageRenderer(bounds: listBounds, format: format).image { context in
            controller.view.layer.render(in: context.cgContext)
        }
    }

    private struct InkMask {
        var inked: [Bool] = []
        var width = 0
        var height = 0
    }

    /// A mask of "inked" pixels — dark OR saturated, which catches both the baseline's black glyph
    /// and the list-tinted blue one while ignoring the white row background and grey separators.
    private static func inkMask(_ image: UIImage) -> InkMask {
        guard let cgImage = image.cgImage else { return InkMask() }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt32](repeating: 0, count: width * height)
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        ) else { return InkMask() }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let inked = pixels.map { pixel in
            let blue = Int(pixel & 0xFF)
            let green = Int((pixel >> 8) & 0xFF)
            let red = Int((pixel >> 16) & 0xFF)
            return (red + green + blue) / 3 < 140 || max(red, green, blue) - min(red, green, blue) > 40
        }
        return InkMask(inked: inked, width: width, height: height)
    }

    /// Measures the leading glyph of every inked band. Bands are contiguous runs of inked
    /// scanlines — separators are not inked, so rows separate cleanly — and within a band the icon
    /// is the first contiguous run of inked columns, before the gap preceding the count text.
    private static func leadingGlyphPerBand(_ image: UIImage) -> [CGSize] {
        let mask = inkMask(image)
        let width = mask.width
        let height = mask.height
        guard width > 0 else { return [] }

        func isInked(column: Int, line: Int) -> Bool {
            mask.inked[line * width + column]
        }

        var bands: [ClosedRange<Int>] = []
        var bandStart: Int?
        for line in 0 ..< height {
            let hasInk = (0 ..< width).contains(where: { isInked(column: $0, line: line) })
            if hasInk {
                bandStart = bandStart ?? line
            } else if let began = bandStart {
                bands.append(began ... (line - 1))
                bandStart = nil
            }
        }
        if let began = bandStart { bands.append(began ... (height - 1)) }

        return bands.map { band in
            let leading = (0 ..< width).first(where: { column in
                band.contains(where: { isInked(column: column, line: $0) })
            })
            guard let leading else { return .zero }
            var trailing = leading
            while trailing + 1 < width,
                  band.contains(where: { isInked(column: trailing + 1, line: $0) }) {
                trailing += 1
            }
            let inkedLines = band.filter { line in
                (leading ... trailing).contains(where: { isInked(column: $0, line: line) })
            }
            let glyphHeight = CGFloat((inkedLines.last ?? 0) - (inkedLines.first ?? 0) + 1) / image.scale
            return CGSize(width: CGFloat(trailing - leading + 1) / image.scale, height: glyphHeight)
        }
    }

    @Test
    func correctedIconMatchesPreSweepBaselineInAList() throws {
        let bands = Self.leadingGlyphPerBand(Self.snapshotImage(Self.comparisonList))
        try #require(bands.count == 4, "expected baseline/unscaled/baseline/corrected rows, got \(bands)")

        let firstBaseline = bands[0]
        let unscaled = bands[1]
        let secondBaseline = bands[2]
        let corrected = bands[3]

        // Measurement self-check: the two baseline rows are the same view, so any drift here means
        // the snapshot, not the scale value, is what changed.
        #expect(firstBaseline == secondBaseline)

        // The regression itself. If this stops holding, a future OS has stopped inflating list
        // label icons and the explicit scale at the six call sites can simply be dropped.
        #expect(unscaled.width > firstBaseline.width + 2)

        // The fix: the corrected icon is back to the pre-sweep glyph, within antialiasing noise.
        #expect(abs(corrected.width - secondBaseline.width) < 0.5)
        #expect(abs(corrected.height - secondBaseline.height) < 0.5)
    }
}
