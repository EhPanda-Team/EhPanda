import AppFeature
import UIKit
import VisualSnapshotSupport
import XCTest

final class RenderServerCaptureTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// 2798 pt at 3x is 8394 px, past the render server ceiling, so the direct draw must fail and the slicer must
    /// reproduce three solid bands across its seam.
    @MainActor
    func testSlicesPastRenderServerDimensionLimit() async throws {
        let fixture = try await BandedWindow.make(size: CGSize(width: 420, height: 2798))
        defer { fixture.tearDown() }
        let root = fixture.root
        let format = fixture.format

        // Pins the limit the slicer exists for: the same hierarchy drawn in one call is refused.
        var drewDirectly = true
        _ = UIGraphicsImageRenderer(bounds: root.view.bounds, format: format).image { _ in
            drewDirectly = root.view.drawHierarchy(in: root.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertFalse(drewDirectly)

        let result = try RenderServerCapture.image(of: root.view, format: format)
        XCTAssertEqual(result.slices.count, 2)
        XCTAssertEqual(result.image.size, CGSize(width: 420, height: 2798))
        XCTAssertEqual(result.image.scale, 3)
        let pixels = try SRGBPixels(image: XCTUnwrap(result.image.cgImage))
        let expectations: [(point: CGPoint, color: UIColor)] = [
            (CGPoint(x: 210, y: 500), .systemRed),
            (CGPoint(x: 210, y: 1500), .systemGreen),
            (CGPoint(x: 210, y: 2700), .systemBlue)
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
        let column = Int(210 * result.image.scale)
        XCTAssertEqual(try pixels.color(column: column, row: pixelSeam - 1),
                       try pixels.color(column: column, row: pixelSeam))
    }

    @MainActor
    func testRejectsWidthPastRenderServerDimensionLimit() async throws {
        let fixture = try await BandedWindow.make(size: CGSize(width: 420, height: 2798))
        defer { fixture.tearDown() }
        let wide = UIView(frame: CGRect(x: 0, y: 0, width: 2731, height: 100))
        fixture.root.view.addSubview(wide)
        defer { wide.removeFromSuperview() }
        XCTAssertThrowsError(try RenderServerCapture.image(of: wide, format: fixture.format)) { error in
            guard case .widthExceedsSnapshotDimension(let width) = error as? RenderServerCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(width, 2731)
        }
    }
}

@MainActor
private struct BandedWindow {
    let window: UIWindow
    let root: UIViewController
    let format: UIGraphicsImageRendererFormat
    let previousKeyWindow: UIWindow?

    static func make(size: CGSize) async throws -> BandedWindow {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
        )
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        let bands: [(color: UIColor, rows: Range<CGFloat>)] = [
            (.systemRed, 0..<1000), (.systemGreen, 1000..<2000), (.systemBlue, 2000..<size.height)
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
