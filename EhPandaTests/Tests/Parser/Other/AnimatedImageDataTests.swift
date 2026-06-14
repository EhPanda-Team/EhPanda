//
//  AnimatedImageDataTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct AnimatedImageDataTests {
    @Test
    func testGIFAnimationRequiresMultipleImageDescriptors() {
        #expect(Data(singleFrameGIFBytes).isAnimatedImageData == false)
        #expect(Data(animatedGIFBytes).isAnimatedImageData == true)
        #expect(Data(singleFrameGIFBytes).animatedImagePasteboardType == nil)
        #expect(Data(animatedGIFBytes).animatedImagePasteboardType != nil)
    }

    @Test
    func testAPNGAnimationControlMustAppearBeforeImageData() {
        let animatedAPNG = Data(Self.pngSignature + pngChunk("acTL") + pngChunk("IDAT"))
        let staticPNG = Data(Self.pngSignature + pngChunk("IDAT") + pngChunk("acTL"))

        #expect(animatedAPNG.isAnimatedImageData == true)
        #expect(staticPNG.isAnimatedImageData == false)
        #expect(animatedAPNG.animatedImagePasteboardType != nil)
        #expect(staticPNG.animatedImagePasteboardType == nil)
    }

    @Test
    func testWebPAnimationUsesExtendedAnimationFlag() {
        let animatedWebP = Data(webPFile(chunks: [
            webPChunk("VP8X", payload: [0x02] + Array(repeating: 0, count: 9))
        ]))
        let staticWebP = Data(webPFile(chunks: [
            webPChunk("VP8X", payload: [0x00] + Array(repeating: 0, count: 9))
        ]))

        #expect(animatedWebP.isAnimatedImageData == true)
        #expect(staticWebP.isAnimatedImageData == false)
        #expect(animatedWebP.animatedImagePasteboardType != nil)
        #expect(staticWebP.animatedImagePasteboardType == nil)
    }

    private static let pngSignature: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    ]

    private var singleFrameGIFBytes: [UInt8] {
        Array("GIF89a".utf8) + [
            0x01, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x00,
            0x2C,
            0x00, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00,
            0x00,
            0x02,
            0x02, 0x4C, 0x01,
            0x00,
            0x3B
        ]
    }

    private var animatedGIFBytes: [UInt8] {
        Array(singleFrameGIFBytes.dropLast()) + [
            0x2C,
            0x00, 0x00, 0x00, 0x00,
            0x01, 0x00, 0x01, 0x00,
            0x00,
            0x02,
            0x02, 0x4C, 0x01,
            0x00,
            0x3B
        ]
    }

    private func pngChunk(_ type: String, payload: [UInt8] = []) -> [UInt8] {
        return bigEndianUInt32(UInt32(payload.count))
            + Array(type.utf8)
            + payload
            + [0x00, 0x00, 0x00, 0x00]
    }

    private func webPFile(chunks: [[UInt8]]) -> [UInt8] {
        let payload = chunks.flatMap { $0 }
        return Array("RIFF".utf8)
            + littleEndianUInt32(4 + payload.count)
            + Array("WEBP".utf8)
            + payload
    }

    private func webPChunk(_ type: String, payload: [UInt8]) -> [UInt8] {
        return Array(type.utf8)
            + littleEndianUInt32(UInt32(payload.count))
            + payload
            + (payload.count.isMultiple(of: 2) ? [] : [0x00])
    }

    private func bigEndianUInt32(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }

    private func littleEndianUInt32(_ value: Int) -> [UInt8] {
        littleEndianUInt32(UInt32(value))
    }

    private func littleEndianUInt32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }
}
