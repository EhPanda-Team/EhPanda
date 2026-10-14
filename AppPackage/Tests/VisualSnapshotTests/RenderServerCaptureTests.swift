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

    @MainActor
    func testTwoCompletePassesPreserveEveryPixelRowAndFinalCrop() throws {
        for scale: CGFloat in [2, 3] {
            let bounds = CGRect(x: 7, y: 11, width: 8, height: 1337 + 1 / scale)
            let viewport = CGSize(width: 8, height: 420)
            let plan = try RenderServerCapture.slicePlan(bounds: bounds, viewportSize: viewport, screenScale: scale)
            var reads: [CGRect] = []
            let result = try RenderServerCapture.capture(
                bounds: bounds, viewportSize: viewport, screenScale: scale, outputScale: scale
            ) { slice in
                reads.append(slice.readFrame)
                return Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: scale)
            }
            expectNoDifference(reads, plan.map(\.readFrame) + plan.map(\.readFrame))
            expectNoDifference(result.raster.pixels, Self.rowRaster(frame: bounds, bounds: bounds, scale: scale).pixels)
            expectNoDifference(
                result.readVerifications.map(\.ownedRows), plan.map({ Self.ownedRows($0, scale: scale) })
            )
            XCTAssertTrue(result.readVerifications.allSatisfy({ $0.secondPass == $0.firstPass }))
            // Read 0 is the native rect: it owns every row, so its gated digest is the whole read's.
            let first = try XCTUnwrap(result.readVerifications.first)
            expectNoDifference(first.ownedRows, 0..<first.pixelHeight)
            expectNoDifference(first.firstPass.owned, first.firstPass.read)
        }
    }

    @MainActor
    func testOriginDependentPixelsAreAcceptedWhenEachRectRepeatsExactly() throws {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let result = try RenderServerCapture.capture(
            bounds: bounds, viewportSize: CGSize(width: 8, height: 420), screenScale: 3, outputScale: 3
        ) { slice in
            let raster = Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
            var pixels = raster.pixels
            // Every read has a different blue channel, including the shared regions. Same-rect reads stay exact.
            let blue = UInt8(Int(slice.readFrame.minY * 3) % 251)
            for byte in stride(from: 2, to: pixels.count, by: 4) { pixels[byte] = blue }
            return CapturedRaster(width: raster.width, height: raster.height, pixels: pixels)
        }
        XCTAssertGreaterThan(Set(result.readVerifications.map(\.firstPass.owned)).count, 1)
        XCTAssertTrue(result.readVerifications.allSatisfy({ $0.secondPass == $0.firstPass }))
    }

    /// Context rows keep read edges away from composed output; final-read overflow is never composed. A change in
    /// either is recorded as whole-read evidence and does not fail the owned-row verification.
    @MainActor
    func testContextAndOverflowChangesAreEvidenceOnly() throws {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let viewport = CGSize(width: 8, height: 420)
        let plan = try RenderServerCapture.slicePlan(bounds: bounds, viewportSize: viewport, screenScale: 3)
        let last = try XCTUnwrap(plan.last)
        let owned = Self.ownedRows(last, scale: 3)
        let readRows = Int(viewport.height * 3)
        XCTAssertGreaterThan(owned.lowerBound, 0)
        XCTAssertLessThan(owned.upperBound, readRows)
        let rowBytes = Int(viewport.width * 3) * 4
        // The first context row, the context row just above the owned rows, the first overflow row and the last.
        let changedBytes = [0, owned.lowerBound * rowBytes - 4, owned.upperBound * rowBytes, readRows * rowBytes - 4]
        for changedByte in changedBytes {
            var count = 0
            let result = try RenderServerCapture.capture(
                bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3
            ) { slice in
                defer { count += 1 }
                let raster = Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
                var pixels = raster.pixels
                if count == plan.count * 2 - 1 { pixels[changedByte] ^= 1 }
                return CapturedRaster(width: raster.width, height: raster.height, pixels: pixels)
            }
            expectNoDifference(count, plan.count * 2)
            expectNoDifference(result.raster.pixels, Self.rowRaster(frame: bounds, bounds: bounds, scale: 3).pixels)
            let record = try XCTUnwrap(result.readVerifications.last)
            expectNoDifference(record.secondPass?.owned, record.firstPass.owned)
            XCTAssertNotEqual(record.secondPass?.read, record.firstPass.read)
            expectNoDifference(record.diagnostics["matched"] as? Bool, true)
            expectNoDifference(record.diagnostics["readMatched"] as? Bool, false)
        }
    }

    /// The first and last composed rows of every read are gated, including read 0's native viewport edge.
    @MainActor
    func testOwnedRowChangesFailInEveryRead() throws {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let viewport = CGSize(width: 8, height: 420)
        let plan = try RenderServerCapture.slicePlan(bounds: bounds, viewportSize: viewport, screenScale: 3)
        let rowBytes = Int(viewport.width * 3) * 4
        for (sliceIndex, slice) in plan.enumerated() {
            let owned = Self.ownedRows(slice, scale: 3)
            for row in [owned.lowerBound, owned.upperBound - 1] {
                var count = 0
                XCTAssertThrowsError(try RenderServerCapture.capture(
                    bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3
                ) { geometry in
                    defer { count += 1 }
                    let raster = Self.rowRaster(frame: geometry.readFrame, bounds: bounds, scale: 3)
                    var pixels = raster.pixels
                    if count == plan.count + sliceIndex { pixels[row * rowBytes + 2] ^= 1 }
                    return CapturedRaster(width: raster.width, height: raster.height, pixels: pixels)
                }) { error in
                    guard case .readChanged(let failedIndex) = error as? RenderServerCaptureError else {
                        return XCTFail("Unexpected error: \(error)")
                    }
                    expectNoDifference(failedIndex, sliceIndex)
                }
                expectNoDifference(count, plan.count + sliceIndex + 1)
            }
        }
    }

    /// One settle pass reads each planned rect once, in order, and digests exactly the rows verification gates.
    @MainActor
    func testSinglePassDigestsCoverExactlyTheVerifiedOwnedRows() throws {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let viewport = CGSize(width: 8, height: 420)
        let plan = try RenderServerCapture.slicePlan(bounds: bounds, viewportSize: viewport, screenScale: 3)
        let verified = try RenderServerCapture.capture(
            bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3
        ) { slice in
            Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
        }
        var reads: [CGRect] = []
        let digests = try RenderServerCapture.ownedRowDigests(
            bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3
        ) { slice in
            reads.append(slice.readFrame)
            return Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
        }
        expectNoDifference(reads, plan.map(\.readFrame))
        expectNoDifference(digests, verified.readVerifications.map(\.firstPass.owned))
        let last = try XCTUnwrap(plan.last)
        let rowBytes = Int(viewport.width * 3) * 4
        for (changedByte, changesDigest) in [(0, false), (Self.ownedRows(last, scale: 3).lowerBound * rowBytes, true)] {
            let changed = try RenderServerCapture.ownedRowDigests(
                bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3
            ) { slice in
                let raster = Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
                var pixels = raster.pixels
                if slice.readFrame == last.readFrame { pixels[changedByte] ^= 1 }
                return CapturedRaster(width: raster.width, height: raster.height, pixels: pixels)
            }
            expectNoDifference(Array(changed.dropLast()), Array(digests.dropLast()))
            expectNoDifference(changed.last != digests.last, changesDigest)
        }
    }

    @MainActor
    func testSecondPassDetectsAChangeDuringTheFirstPass() throws {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let viewport = CGSize(width: 8, height: 420)
        let plan = try RenderServerCapture.slicePlan(bounds: bounds, viewportSize: viewport, screenScale: 3)
        var count = 0
        XCTAssertThrowsError(try RenderServerCapture.capture(
            bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3
        ) { slice in
            defer { count += 1 }
            let raster = Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
            var pixels = raster.pixels
            if count > 0 { pixels[0] ^= 1 }
            return CapturedRaster(width: raster.width, height: raster.height, pixels: pixels)
        }) { error in
            guard case .readChanged(let sliceIndex) = error as? RenderServerCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
            expectNoDifference(sliceIndex, 0)
        }
        expectNoDifference(count, plan.count + 1)
    }

    @MainActor
    func testUnexpectedReadDimensionsFailBeforeComposition() {
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let viewport = CGSize(width: 8, height: 420)
        let wrongSize = { (_: RenderServerCapture.Slice) in
            CapturedRaster(width: 1, height: 1, pixels: Data([0, 0, 0, 255]))
        }
        XCTAssertThrowsError(try RenderServerCapture.capture(
            bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3, read: wrongSize
        )) { error in
            guard case .unexpectedReadSize = error as? RenderServerCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(try RenderServerCapture.ownedRowDigests(
            bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3, read: wrongSize
        )) { error in
            guard case .unexpectedReadSize = error as? RenderServerCaptureError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    /// An owned-row change keeps both whole reads, context included, and records every read's evidence so far.
    @MainActor
    func testReadFailureDiagnosticsKeepBothWholeReads() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "read-verification-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                XCTFail("Diagnostic cleanup failed: \(error)")
            }
        }
        let bounds = CGRect(x: 0, y: 0, width: 8, height: 1337)
        let viewport = CGSize(width: 8, height: 420)
        let plan = try RenderServerCapture.slicePlan(bounds: bounds, viewportSize: viewport, screenScale: 3)
        let second = try XCTUnwrap(plan.dropFirst().first)
        let ownedByte = Self.ownedRows(second, scale: 3).lowerBound * Int(viewport.width * 3) * 4
        let original = Self.rowRaster(frame: second.readFrame, bounds: bounds, scale: 3)
        var changedPixels = original.pixels
        changedPixels[ownedByte] ^= 1
        let changed = CapturedRaster(width: original.width, height: original.height, pixels: changedPixels)
        var count = 0
        XCTAssertThrowsError(try RenderServerCapture.capture(
            bounds: bounds, viewportSize: viewport, screenScale: 3, outputScale: 3,
            diagnosticsDirectory: directory
        ) { slice in
            defer { count += 1 }
            return count == plan.count + 1 ? changed : Self.rowRaster(frame: slice.readFrame, bounds: bounds, scale: 3)
        })
        for (pass, expected) in [(1, original), (2, changed)] {
            let imagePath = directory.appending(path: "capture.read-1.pass-\(pass).png").path(percentEncoded: false)
            let image = try XCTUnwrap(UIImage(contentsOfFile: imagePath)?.cgImage)
            expectNoDifference(try CapturedRaster(image: image).pixels, expected.pixels)
        }
        let data = try Data(contentsOf: directory.appending(path: "render-read-verification.json"))
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        expectNoDifference(report["status"] as? String, "failed")
        expectNoDifference(report["failedSliceIndex"] as? Int, 1)
        let reads = try XCTUnwrap(report["reads"] as? [[String: Any]])
        let unreached: [Bool?] = Array(repeating: nil, count: plan.count - 2)
        expectNoDifference(reads.map({ $0["matched"] as? Bool }), [true, false] + unreached)
        let failed = try XCTUnwrap(reads.dropFirst().first)
        let ownedRows = Self.ownedRows(second, scale: 3)
        expectNoDifference(failed["ownedRows"] as? [Int], [ownedRows.lowerBound, ownedRows.upperBound])
        XCTAssertNotEqual(failed["firstPassOwnedSHA256"] as? String, failed["secondPassOwnedSHA256"] as? String)
        expectNoDifference(failed["readMatched"] as? Bool, false)
    }

    @MainActor
    func testNativeCompositionPreservesEveryEncodedPixelRow() async throws {
        let scene = try BandedWindow.activeScene()
        let scale = scene.screen.scale
        let fixture = try await BandedWindow.make(in: scene, height: scene.screen.bounds.height * 2 + 17 / scale)
        defer { fixture.tearDown() }
        let expected = Self.rowRaster(frame: fixture.root.view.bounds, bounds: fixture.root.view.bounds, scale: scale)
        let artwork = UIImageView(image: try expected.comparisonImage(scale: scale))
        artwork.frame = fixture.root.view.bounds
        fixture.root.view.addSubview(artwork)
        await DisplayFrame.wait()
        await DisplayFrame.wait()
        let result = try RenderServerCapture.image(
            of: fixture.root.view, viewportSize: scene.screen.bounds.size, format: fixture.format
        )
        expectNoDifference(result.raster.pixels, expected.pixels)
        XCTAssertTrue(result.readVerifications.allSatisfy({ $0.secondPass == $0.firstPass }))
    }

    /// Read-local pixel rows a slice contributes to the composite.
    private static func ownedRows(_ slice: RenderServerCapture.Slice, scale: CGFloat) -> Range<Int> {
        let start = Int(((slice.frame.minY - slice.readFrame.minY) * scale).rounded())
        return start..<start + Int((slice.frame.height * scale).rounded())
    }

    /// Each row carries its absolute row number in RG and each column carries its index in B.
    private static func rowRaster(frame: CGRect, bounds: CGRect, scale: CGFloat) -> CapturedRaster {
        let width = Int((frame.width * scale).rounded())
        let height = Int((frame.height * scale).rounded())
        let firstRow = Int(((frame.minY - bounds.minY) * scale).rounded())
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            for row in 0..<height {
                for column in 0..<width {
                    let byte = (row * width + column) * 4
                    buffer[byte] = UInt8((firstRow + row) & 255)
                    buffer[byte + 1] = UInt8(((firstRow + row) >> 8) & 255)
                    buffer[byte + 2] = UInt8(column & 255)
                    buffer[byte + 3] = 255
                }
            }
        }
        return CapturedRaster(width: width, height: height, pixels: pixels)
    }

    func testFirstReadOwnsNativeEdgeRowsAndPreservesInteriorContext() throws {
        let plan = try RenderServerCapture.slicePlan(
            bounds: CGRect(x: 0, y: 0, width: 420, height: 4039.0 / 3),
            viewportSize: CGSize(width: 420, height: 912), screenScale: 3
        )
        expectNoDifference(plan.count, 2)
        let first = try XCTUnwrap(plan.first)
        let second = try XCTUnwrap(plan.last)
        expectNoDifference(first.frame, CGRect(x: 0, y: 0, width: 420, height: 912))
        expectNoDifference(first.readFrame, first.frame)
        XCTAssertNil(first.contextFrame)
        expectNoDifference(second.frame.minY, 912)
        expectNoDifference(second.contextFrame, CGRect(x: 0, y: 784, width: 420, height: 64))
        expectNoDifference(second.readFrame.minY, 720)
        expectNoDifference(second.readFrame.size, first.readFrame.size)
    }

    func testFinalViewportReadExtendsPastContentWithoutOwningExcessRows() throws {
        for origin in [CGPoint.zero, CGPoint(x: 7, y: 11)] {
            let bounds = CGRect(origin: origin, size: CGSize(width: 1210, height: 5196))
            let plan = try RenderServerCapture.slicePlan(
                bounds: bounds, viewportSize: CGSize(width: 1210, height: 834), screenScale: 2
            )
            expectNoDifference(plan.count, 8)
            let last = try XCTUnwrap(plan.last)
            expectNoDifference(last.readFrame,
                               CGRect(x: 0, y: 4480, width: 1210, height: 834).offsetBy(dx: origin.x, dy: origin.y))
            expectNoDifference(last.frame,
                               CGRect(x: 0, y: 4610, width: 1210, height: 586).offsetBy(dx: origin.x, dy: origin.y))
            expectNoDifference(last.contextFrame,
                               CGRect(x: 0, y: 4546, width: 1210, height: 64).offsetBy(dx: origin.x, dy: origin.y))
            expectNoDifference(last.frame.maxY, bounds.maxY)
        }
    }

    func testSlicePlanPartitionsPixelsAcrossNativeDeviceGeometries() throws {
        let viewports: [(size: CGSize, scale: CGFloat)] = [
            (CGSize(width: 420, height: 912), 3), (CGSize(width: 912, height: 420), 3),
            (CGSize(width: 834, height: 1210), 2), (CGSize(width: 1210, height: 834), 2)
        ]
        for viewport in viewports {
            let scale = viewport.scale
            let viewportRows = Int((viewport.size.height * scale).rounded())
            let maximumRows = Int(RenderServerCapture.maximumSliceHeight(forScreenScale: scale) * scale)
            let width = Int(viewport.size.width * scale)
            let heights = [viewportRows, viewportRows + 1, maximumRows - 1, maximumRows, maximumRows + 1,
                           maximumRows * 3 + 17, RenderServerCapture.maximumCompositePixelCount / width]
            for height in heights {
                let bounds = CGRect(x: 0, y: 0, width: viewport.size.width, height: CGFloat(height) / scale)
                let plan = try RenderServerCapture.slicePlan(
                    bounds: bounds, viewportSize: viewport.size, screenScale: scale
                )
                let first = try XCTUnwrap(plan.first)
                expectNoDifference(first.readFrame, CGRect(origin: .zero, size: viewport.size))
                expectNoDifference(first.frame, first.readFrame)
                var ownedEnd = 0
                var previousRead: CGRect?
                for slice in plan {
                    let read = slice.readFrame.applying(CGAffineTransform(scaleX: scale, y: scale))
                    let frame = slice.frame.applying(CGAffineTransform(scaleX: scale, y: scale))
                    expectNoDifference(Int(frame.minY.rounded()), ownedEnd)
                    XCTAssertGreaterThan(frame.height, 0)
                    XCTAssertGreaterThanOrEqual(frame.minY, read.minY - 0.0001)
                    XCTAssertLessThanOrEqual(frame.maxY, read.maxY + 0.0001)
                    expectNoDifference(slice.readFrame.size, viewport.size)
                    XCTAssertLessThanOrEqual(frame.maxY, CGFloat(height) + 0.0001)
                    let origin = Int(read.minY.rounded())
                    expectNoDifference(origin % 16, 0)
                    expectNoDifference(origin % 2, 0)
                    if let previousRead {
                        let seam = try XCTUnwrap(slice.contextFrame)
                            .applying(CGAffineTransform(scaleX: scale, y: scale))
                        expectNoDifference(Int(seam.height.rounded()), Int(64 * scale))
                        XCTAssertLessThanOrEqual(seam.maxY, CGFloat(height) + 0.0001)
                        for enclosing in [previousRead, read] {
                            XCTAssertGreaterThanOrEqual(seam.minY - enclosing.minY, 64 * scale - 0.0001)
                            XCTAssertGreaterThanOrEqual(enclosing.maxY - seam.maxY, 64 * scale - 0.0001)
                        }
                    } else {
                        XCTAssertNil(slice.contextFrame)
                    }
                    ownedEnd = Int(frame.maxY.rounded())
                    previousRead = read
                }
                expectNoDifference(ownedEnd, height)
            }
        }
    }

    func testSlicePlanRejectsIncompatibleNativeViewport() {
        for viewport in [CGSize(width: 419, height: 912), CGSize(width: 420, height: 2000),
                         CGSize(width: 420, height: 100), CGSize(width: 420, height: 256)] {
            XCTAssertThrowsError(try RenderServerCapture.slicePlan(
                bounds: CGRect(x: 0, y: 0, width: 420, height: 1400),
                viewportSize: viewport, screenScale: 3
            ))
        }
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

        let result = try RenderServerCapture.image(
            of: root.view, viewportSize: scene.screen.bounds.size, format: format
        )
        XCTAssertGreaterThan(result.slices.count, 2)
        for slice in result.slices {
            expectNoDifference(slice.readFrame.size, scene.screen.bounds.size)
            XCTAssertLessThanOrEqual(slice.frame.maxY, height)
        }
        XCTAssertGreaterThan(try XCTUnwrap(result.slices.last).readFrame.maxY, height)
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
        // The final full-height replicant extends beyond the window. Only its in-bounds blue tail is composed.
        expectNoDifference(try pixels.color(column: column, row: pixels.height - 1),
                           try pixels.color(column: column, row: pixels.height * 5 / 6))
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
        let result = try RenderServerCapture.image(
            of: fixture.root.view, viewportSize: scene.screen.bounds.size, format: fixture.format
        )
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
        XCTAssertThrowsError(try RenderServerCapture.image(
            of: refused, viewportSize: scene.screen.bounds.size, format: fixture.format
        )) { error in
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
        XCTAssertThrowsError(try RenderServerCapture.image(
            of: wide, viewportSize: scene.screen.bounds.size, format: fixture.format
        )) { error in
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

/// 8-bit sRGB premultiplied RGBA bytes, the same pixel convention the capture's same-rect verification compares.
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
                bitmapInfo: .init(alpha: .premultipliedLast, byteOrder: .order32Big)
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
