import AppFeature
import CustomDump
import Darwin
import UIKit
@testable import VisualSnapshotSupport
import XCTest

final class RenderServerCaptureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// The window is the smallest point height past the direct-draw ceiling on the running device (2731 pt at 3x
    /// is 8193 px, 4097 pt at 2x is 8194 px; 8192 px is the last height the direct path accepts, measured), so the
    /// direct draw must fail and the slicer must reproduce three solid bands across its seam.
    @MainActor
    func testSlicesPastRenderServerDimensionLimit() async throws {
        let scene = try BandedWindow.activeScene()
        let scale = scene.screen.scale
        let height = floor(BandedWindow.directDrawCeiling / scale) + 1
        let fixture = try await BandedWindow.make(in: scene, height: height)
        defer { fixture.tearDown() }
        let root = fixture.root
        let format = fixture.format
        let width = fixture.window.bounds.width

        // Pins the limit the slicer exists for: the same hierarchy drawn in one call is refused.
        var drewDirectly = true
        _ = UIGraphicsImageRenderer(bounds: root.view.bounds, format: format).image { _ in
            drewDirectly = root.view.drawHierarchy(in: root.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertFalse(drewDirectly)

        let result = try RenderServerCapture.image(of: root.view, format: format)
        XCTAssertEqual(result.slices.count, 2)
        XCTAssertEqual(result.image.size, CGSize(width: width, height: height))
        XCTAssertEqual(result.image.scale, scale)
        let pixels = try SRGBPixels(image: XCTUnwrap(result.image.cgImage))
        let expectations: [(point: CGPoint, color: UIColor)] = [
            (CGPoint(x: width / 2, y: height / 6), .systemRed),
            (CGPoint(x: width / 2, y: height / 2), .systemGreen),
            (CGPoint(x: width / 2, y: height * 5 / 6), .systemBlue)
        ]
        for expectation in expectations {
            let actual = try pixels.color(at: expectation.point, scale: result.image.scale)
            let expected = try SRGBPixels.color(of: expectation.color.resolvedColor(with: root.view.traitCollection))
            XCTAssertEqual(actual.count, expected.count)
            for (actualChannel, expectedChannel) in zip(actual, expected) {
                XCTAssertLessThanOrEqual(abs(Int(actualChannel) - Int(expectedChannel)), 2,
                                         "\(expectation.point): \(actual) vs \(expected)")
            }
        }
        let seam = try XCTUnwrap(result.slices.first).frame.maxY
        let pixelSeam = Int((seam * result.image.scale).rounded())
        let column = Int(width / 2 * result.image.scale)
        XCTAssertEqual(try pixels.color(column: column, row: pixelSeam - 1),
                       try pixels.color(column: column, row: pixelSeam))
    }

    /// The largest whole row count within the area policy, plus the first row the policy rejects.
    @MainActor
    func testCompositePixelBudgetBoundary() async throws {
        let scene = try BandedWindow.activeScene()
        let scale = scene.screen.scale
        let pixelWidth = Int((scene.screen.bounds.width * scale).rounded())
        let budget = RenderServerCapture.maximumCompositePixelCount
        let pixelHeight = budget / pixelWidth
        var measurements = [try ProcessFootprint.sample(stage: "before-window")]
        let fixture = try await BandedWindow.make(in: scene, height: CGFloat(pixelHeight) / scale)
        defer { fixture.tearDown() }
        measurements.append(try ProcessFootprint.sample(stage: "before-composite"))
        let start = ContinuousClock.now
        let result = try RenderServerCapture.image(of: fixture.root.view, format: fixture.format)
        let elapsed = start.duration(to: .now) / .milliseconds(1)
        measurements.append(try ProcessFootprint.sample(stage: "after-composite"))
        let image = try XCTUnwrap(result.image.cgImage)
        expectNoDifference(image.width, pixelWidth)
        expectNoDifference(image.height, pixelHeight)
        XCTAssertLessThanOrEqual(pixelWidth * pixelHeight, budget)
        XCTAssertGreaterThan(pixelWidth * (pixelHeight + 1), budget)
        let expectations: [(row: Int, color: UIColor)] = [
            (pixelHeight / 6, .systemRed), (pixelHeight / 2, .systemGreen), (pixelHeight * 5 / 6, .systemBlue)
        ]
        for expectation in expectations {
            let actual = try Self.pixel(image, column: pixelWidth / 2, row: expectation.row)
            let color = expectation.color.resolvedColor(with: fixture.root.view.traitCollection)
            let expected = try SRGBPixels.color(of: color)
            for (actualChannel, expectedChannel) in zip(actual, expected) {
                XCTAssertLessThanOrEqual(abs(Int(actualChannel) - Int(expectedChannel)), 2)
            }
        }
        for slice in result.slices.dropFirst() {
            let row = Int((slice.frame.minY * scale).rounded())
            expectNoDifference(
                try Self.pixel(image, column: pixelWidth / 2, row: row - 1),
                try Self.pixel(image, column: pixelWidth / 2, row: row)
            )
        }
        // The census receives the very same canonical storage; no full-size redraw for inspection.
        let raster = result.raster
        expectNoDifference(raster.pixels.count, pixelWidth * pixelHeight * 4)
        let first = (pixelHeight / 6 * pixelWidth + pixelWidth / 2) * 4
        expectNoDifference(Array(raster.pixels[first..<first + 4]), try Self.pixel(
            image, column: pixelWidth / 2, row: pixelHeight / 6
        ))
        measurements.append(try ProcessFootprint.sample(stage: "after-census-reuse"))
        let pngBytes = try autoreleasepool { try XCTUnwrap(result.image.pngData()).count }
        measurements.append(try ProcessFootprint.sample(stage: "after-png"))
        let refused = UIView(frame: CGRect(
            x: 0, y: 0, width: fixture.root.view.bounds.width, height: CGFloat(pixelHeight + 1) / scale
        ))
        fixture.root.view.addSubview(refused)
        defer { refused.removeFromSuperview() }
        XCTAssertThrowsError(try RenderServerCapture.image(of: refused, format: fixture.format)) { error in
            guard case .compositeExceedsBudget(let width, let height) = error as? RenderServerCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
            expectNoDifference(width, pixelWidth)
            expectNoDifference(height, pixelHeight + 1)
        }
        let evidence: [String: Any] = [
            "maximumCompositePixelCount": budget, "pixelWidth": pixelWidth, "pixelHeight": pixelHeight,
            "pixelCount": pixelWidth * pixelHeight, "rgbaBytes": pixelWidth * pixelHeight * 4,
            "unusedBudgetPixels": budget - pixelWidth * pixelHeight, "sliceCount": result.slices.count,
            "compositeMilliseconds": elapsed, "pngBytes": pngBytes, "measurements": measurements
        ]
        let attachment = XCTAttachment(
            data: try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys]),
            uniformTypeIdentifier: "public.json"
        )
        attachment.name = "phase17-composite-budget-footprint"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func pixel(_ image: CGImage, column: Int, row: Int) throws -> [UInt8] {
        let crop = try XCTUnwrap(image.cropping(to: CGRect(x: column, y: row, width: 1, height: 1)))
        return try SRGBPixels(image: crop).color(column: 0, row: 0)
    }

    func testMaximumSliceHeightStaysBelowSilentBlackCeiling() {
        // 4096 pt at 2x (8192 px) is the measured read that draws successfully but returns all black.
        XCTAssertEqual(RenderServerCapture.maximumSliceHeight(forScreenScale: 2), 4095)
        XCTAssertEqual(RenderServerCapture.maximumSliceHeight(forScreenScale: 3), 2730)
        XCTAssertEqual(RenderServerCapture.maximumSliceHeight(forScreenScale: 1), 8191)
    }

    /// One point wider than the widest read on the running device (2731 pt at 3x, 4096 pt at 2x, both 8192 px or
    /// more), so the capture must refuse the width rather than slice it.
    @MainActor
    func testRejectsWidthPastRenderServerDimensionLimit() async throws {
        let scene = try BandedWindow.activeScene()
        let wideWidth = RenderServerCapture.maximumSliceHeight(forScreenScale: scene.screen.scale) + 1
        let fixture = try await BandedWindow.make(in: scene, height: scene.screen.bounds.height)
        defer { fixture.tearDown() }
        let wide = UIView(frame: CGRect(x: 0, y: 0, width: wideWidth, height: 100))
        fixture.root.view.addSubview(wide)
        defer { wide.removeFromSuperview() }
        XCTAssertThrowsError(try RenderServerCapture.image(of: wide, format: fixture.format)) { error in
            guard case .widthExceedsSnapshotDimension(let width) = error as? RenderServerCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(width, wideWidth)
        }
    }
}

/// A key window of three solid color bands, each a third of its height, spanning the scene's full width.
///
/// The width is the scene's screen width, never a fixed phone width: on the 2x iPad a window narrower than its
/// scene is composited opaque black on every capture path while `drawHierarchy` still returns `true` (measured
/// 2026-10-03; a scene-width window renders correctly on every path), so a narrower fixture would test nothing.
@MainActor
private struct BandedWindow {
    /// The tallest height, in screen pixels, that a direct `drawHierarchy` accepts (measured 2026-10-03).
    static let directDrawCeiling: CGFloat = 8192

    let window: UIWindow
    let root: UIViewController
    let format: UIGraphicsImageRendererFormat
    let previousKeyWindow: UIWindow?

    static func activeScene() throws -> UIWindowScene {
        try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
    }

    static func make(in scene: UIWindowScene, height: CGFloat) async throws -> BandedWindow {
        let size = CGSize(width: scene.screen.bounds.width, height: height)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        let bands: [(color: UIColor, rows: Range<CGFloat>)] = [
            (.systemRed, 0..<height / 3), (.systemGreen, height / 3..<height * 2 / 3),
            (.systemBlue, height * 2 / 3..<height)
        ]
        for band in bands {
            let view = UIView(frame: CGRect(
                x: 0, y: band.rows.lowerBound, width: size.width, height: band.rows.upperBound - band.rows.lowerBound
            ))
            view.backgroundColor = band.color
            view.autoresizingMask = [.flexibleWidth]
            root.view.addSubview(view)
        }
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.frame = CGRect(origin: .zero, size: size)
        root.view.frame = window.bounds
        window.layoutIfNeeded()
        await DisplayFrame.wait()
        await DisplayFrame.wait()
        let format = UIGraphicsImageRendererFormat(for: window.traitCollection)
        format.scale = window.screen.scale
        format.opaque = true
        format.preferredRange = .standard
        return BandedWindow(window: window, root: root, format: format, previousKeyWindow: previousKeyWindow)
    }

    func tearDown() {
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
}

/// 8-bit sRGB premultiplied RGBA bytes, the same pixel convention the capture's seam check compares.
private struct SRGBPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(image: CGImage) throws {
        width = image.width
        height = image.height
        bytes = try Self.render(width: width, height: height) { context in
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
    }

    static func color(of color: UIColor) throws -> [UInt8] {
        try render(width: 1, height: 1) { context in
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    func color(at point: CGPoint, scale: CGFloat) throws -> [UInt8] {
        try color(column: Int(point.x * scale), row: Int(point.y * scale))
    }

    func color(column: Int, row: Int) throws -> [UInt8] {
        guard (0..<width).contains(column), (0..<height).contains(row) else {
            throw SRGBPixelsError.outOfBounds(column: column, row: row)
        }
        let start = (row * width + column) * 4
        return Array(bytes[start..<start + 4])
    }

    private static func render(width: Int, height: Int, drawing: (CGContext) -> Void) throws -> [UInt8] {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drew = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            drawing(context)
            return true
        }
        guard drew else { throw SRGBPixelsError.contextUnavailable }
        return bytes
    }
}

private enum SRGBPixelsError: Error {
    case contextUnavailable
    case outOfBounds(column: Int, row: Int)
}

/// Resumes after the next display refresh, so layout and drawing have been committed to the render server.
@MainActor
private final class DisplayFrame: NSObject {
    private var continuation: CheckedContinuation<Void, Never>?
    private var displayLink: CADisplayLink?

    static func wait() async {
        let frame = DisplayFrame()
        await withCheckedContinuation { continuation in
            frame.continuation = continuation
            let link = CADisplayLink(target: frame, selector: #selector(frame.didDisplay))
            frame.displayLink = link
            link.add(to: .main, forMode: .common)
        }
    }

    @objc private func didDisplay() {
        displayLink?.invalidate()
        displayLink = nil
        continuation?.resume()
        continuation = nil
    }
}

private enum ProcessFootprint {
    static func sample(stage: String) throws -> [String: Any] {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { throw FootprintError.taskInfo(result) }
        return [
            "stage": stage, "physFootprintBytes": info.phys_footprint,
            "ledgerPhysFootprintPeakBytes": info.ledger_phys_footprint_peak
        ]
    }
}

private enum FootprintError: Error {
    case taskInfo(kern_return_t)
}
