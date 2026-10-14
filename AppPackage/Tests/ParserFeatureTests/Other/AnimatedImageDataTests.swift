import AnimatedImageFeature
@testable import AppFeature
import Foundation
import Testing

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

    @Test
    func truncatedChunkHeadersAndOversizedPayloadsAreNotAnimated() {
        let apng = Data(Self.pngSignature + pngChunk("acTL", payload: [1]))
        for length in 0..<apng.count {
            #expect(apng.prefix(length).isAnimatedImageData == false)
        }

        let webP = Data(webPFile(chunks: [webPChunk("VP8X", payload: [0x02])]))
        for length in 0..<webP.count {
            #expect(webP.prefix(length).isAnimatedImageData == false)
        }

        let oversizedPNG = Data(Self.pngSignature + bigEndianUInt32(.max) + Array("acTL".utf8) + [0, 0, 0, 0])
        let oversizedWebP = Data(webPFile(chunks: [
            Array("VP8X".utf8) + littleEndianUInt32(UInt32.max) + [0x02, 0, 0, 0]
        ]))
        #expect(oversizedPNG.isAnimatedImageData == false)
        #expect(oversizedWebP.isAnimatedImageData == false)
    }

    @Test(arguments: [1, 3, 7])
    func readsUnalignedChunksFromDataSlices(_ prefixCount: Int) {
        let images = [
            Data(animatedGIFBytes),
            Data(Self.pngSignature + pngChunk("acTL") + pngChunk("IDAT")),
            Data(webPFile(chunks: [webPChunk("VP8X", payload: [0x02])]))
        ]
        for image in images {
            let padded = Data(repeating: 0, count: prefixCount) + image
            let slice = padded.dropFirst(prefixCount)
            #expect(slice.startIndex == prefixCount)
            #expect(slice.isAnimatedImageData == true)
        }
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
        let payload = chunks.flatMap({ $0 })
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
