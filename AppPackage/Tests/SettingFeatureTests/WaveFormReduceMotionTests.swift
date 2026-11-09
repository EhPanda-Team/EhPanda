import Foundation
@testable import SettingFeature
import SwiftUI
import Testing
import UIKit

/// The Login page's backdrop waves (19-10). They slide sideways for as long as the page is open, driven by the wall
/// clock: a continuous position change, which D-29 gates on Reduce Motion. Under Reduce Motion the waves stand still
/// at a fixed phase, so the page also settles for the snapshot matrix; without it they keep sliding.
///
/// Rendered through the public view with the environment value set, twice, a quarter of a second apart: that is
/// 1/16 of a cycle, about 12 pt at the 200 pt width here, so a moving wave cannot render the same pixels twice.
@MainActor
struct WaveFormReduceMotionTests {
    @Test
    func underReduceMotionThePhaseDoesNotFollowTheClock() {
        let first = Date(timeIntervalSinceReferenceDate: 1_000)
        let later = first.addingTimeInterval(1.3)

        #expect(WaveForm.phase(at: first, reduceMotion: true) == 0)
        #expect(WaveForm.phase(at: later, reduceMotion: true) == 0)
        #expect(WaveForm.phase(at: first, reduceMotion: false) != WaveForm.phase(at: later, reduceMotion: false))
    }

    @Test
    func underReduceMotionTwoRendersAtDifferentTimesAreIdentical() async throws {
        let first = try Self.render(reduceMotion: true)
        try await Task.sleep(for: .milliseconds(250))
        let later = try Self.render(reduceMotion: true)

        #expect(first.inked > Self.minimumInkedPixels, "The wave drew \(first.inked) pixels: nothing to compare.")
        #expect(first.bytes == later.bytes, "The wave moved between two renders under Reduce Motion.")
    }

    @Test
    func withoutReduceMotionTheWavesStillSlide() async throws {
        let first = try Self.render(reduceMotion: false)
        try await Task.sleep(for: .milliseconds(250))
        let later = try Self.render(reduceMotion: false)

        #expect(first.inked > Self.minimumInkedPixels, "The wave drew \(first.inked) pixels: nothing to compare.")
        #expect(first.bytes != later.bytes, "The wave stood still without Reduce Motion.")
    }

    /// The filled half of a 200 × 100 pt canvas at scale 2 is about 20,000 pixels; a blank render has none.
    private static let minimumInkedPixels = 5_000

    private struct Render {
        let bytes: [UInt8]
        /// Pixels with any opacity.
        let inked: Int
    }

    private static func render(reduceMotion: Bool) throws -> Render {
        let renderer = ImageRenderer(
            content: WaveForm(color: .black, amplify: 30, isReversed: false)
                .frame(width: 200, height: 100)
                .environment(\._accessibilityReduceMotion, reduceMotion)
        )
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "The wave did not render.")
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let inked = stride(from: 3, to: bytes.count, by: 4).filter({ bytes[$0] > 0 }).count
        return Render(bytes: bytes, inked: inked)
    }
}
