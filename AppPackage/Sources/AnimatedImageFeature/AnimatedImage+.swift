import UIKit
import SDWebImage
import UniformTypeIdentifiers

private enum ImageDataSignature {
    public static let jpeg: [UInt8] = [0xFF, 0xD8, 0xFF]
    public static let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    public static let pngComplete: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    public static let gif = Array("GIF".utf8)
    public static let riff = Array("RIFF".utf8)
    public static let webp = Array("WEBP".utf8)
    public static let webPExtended = Array("VP8X".utf8)
    public static let webPAnimation = Array("ANIM".utf8)
    public static let apngAnimationControl = Array("acTL".utf8)
    public static let pngImageData = Array("IDAT".utf8)
}

extension Data {
    public var knownBinaryImageFileExtension: String? {
        if isJPEGFormat {
            return "jpg"
        }
        if isPNGFormat {
            return "png"
        }
        if isGIFFormat {
            return "gif"
        }
        if isWebPFormat {
            return "webp"
        }
        return nil
    }

    public var isKnownBinaryImageFormat: Bool {
        knownBinaryImageFileExtension != nil
    }

    public var isJPEGFormat: Bool {
        starts(with: ImageDataSignature.jpeg)
    }

    public var isPNGFormat: Bool {
        starts(with: ImageDataSignature.png)
    }

    public var isAPNGFormat: Bool {
        guard starts(with: ImageDataSignature.pngComplete) else { return false }
        // Walk the chunk headers in place; a still PNG returns at the first `IDAT`
        // after reading only a few header bytes, so no full-image copy is needed.
        return withUnsafeBytes { bytes in
            var offset = ImageDataSignature.pngComplete.count
            while offset + 12 <= bytes.count {
                let chunkLength = Int(Self.bigEndianUInt32(bytes, offset: offset))
                let chunkTypeOffset = offset + 4
                let chunkDataOffset = offset + 8
                guard chunkDataOffset + chunkLength + 4 <= bytes.count else { return false }
                if Self.matches(ImageDataSignature.apngAnimationControl, in: bytes, at: chunkTypeOffset) {
                    return true
                }
                if Self.matches(ImageDataSignature.pngImageData, in: bytes, at: chunkTypeOffset) {
                    return false
                }
                offset = chunkDataOffset + chunkLength + 4
            }
            return false
        }
    }

    public var isGIFFormat: Bool {
        starts(with: ImageDataSignature.gif)
    }

    public var isWebPFormat: Bool {
        starts(with: ImageDataSignature.riff)
            && hasBytes(ImageDataSignature.webp, at: 8)
    }

    /// Whether the bytes are an image that *actually animates*. This is the routing key for
    /// rendering and export: animated data is rendered by SDWebImage, still data by
    /// Kingfisher / `UIImage`. The decision is made from the bytes themselves (GIF frame
    /// count, APNG `acTL` before `IDAT`, WebP VP8X animation bit), never the URL's file
    /// extension: the extension is known before any bytes exist and is wrong for mislabeled
    /// or content-negotiated images.
    public var isAnimatedImageData: Bool {
        isAnimatedGIFFormat || isAPNGFormat || isAnimatedWebPFormat
    }

    public var animatedImagePasteboardType: String? {
        if isAnimatedWebPFormat {
            return UTType.webP.identifier
        }
        if isAPNGFormat {
            return UTType.png.identifier
        }
        if isAnimatedGIFFormat {
            return UTType.gif.identifier
        }
        return nil
    }

    public var decodedImage: UIImage? {
        if isAnimatedImageData, let animatedImage = SDAnimatedImage(data: self) {
            return animatedImage
        }
        return UIImage(data: self)
    }

    private func hasBytes(_ bytes: [UInt8], at offset: Int) -> Bool {
        guard count >= offset + bytes.count else { return false }
        let start = index(startIndex, offsetBy: offset)
        let end = index(start, offsetBy: bytes.count)
        return self[start..<end].elementsEqual(bytes)
    }

    private var isAnimatedGIFFormat: Bool {
        guard isGIFFormat else { return false }
        return withUnsafeBytes { bytes in
            guard bytes.count >= 13, let screenDescriptor = Self.byte(bytes, at: 10) else { return false }

            var offset = 13
            if screenDescriptor & 0x80 != 0 {
                offset += Self.colorTableByteCount(packedField: screenDescriptor)
            }

            var imageCount = 0
            while let blockLabel = Self.byte(bytes, at: offset) {
                switch blockLabel {
                case 0x2C:
                    imageCount += 1
                    guard imageCount <= 1 else { return true }
                    guard offset + 10 <= bytes.count,
                          let packedField = Self.byte(bytes, at: offset + 9)
                    else { return false }
                    offset += 10
                    if packedField & 0x80 != 0 {
                        offset += Self.colorTableByteCount(packedField: packedField)
                    }
                    guard offset < bytes.count else { return false }
                    offset += 1
                    guard Self.skipGIFSubBlocks(bytes, offset: &offset) else { return false }

                case 0x21:
                    offset += 2
                    guard Self.skipGIFSubBlocks(bytes, offset: &offset) else { return false }

                case 0x3B:
                    return false

                default:
                    return false
                }
            }
            return false
        }
    }

    private var isAnimatedWebPFormat: Bool {
        guard isWebPFormat else { return false }
        return withUnsafeBytes { bytes in
            var offset = 12
            while offset + 8 <= bytes.count {
                let chunkTypeOffset = offset
                let chunkSize = Int(Self.littleEndianUInt32(bytes, offset: offset + 4))
                let chunkDataOffset = offset + 8
                let paddedChunkSize = chunkSize + (chunkSize % 2)
                guard chunkDataOffset + paddedChunkSize <= bytes.count else { return false }

                if Self.matches(ImageDataSignature.webPExtended, in: bytes, at: chunkTypeOffset) {
                    guard chunkSize >= 1 else { return false }
                    return bytes[chunkDataOffset] & 0x02 != 0
                }
                if Self.matches(ImageDataSignature.webPAnimation, in: bytes, at: chunkTypeOffset) {
                    return true
                }
                offset = chunkDataOffset + paddedChunkSize
            }
            return false
        }
    }

    private static func colorTableByteCount(packedField: UInt8) -> Int {
        3 * (1 << Int((packedField & 0x07) + 1))
    }

    /// The byte at `offset`, or `nil` when it lies outside the buffer.
    ///
    /// Every read below comes from a length field or a walk cursor in untrusted image data, so the
    /// bounds check belongs at the read rather than at each caller, where it is easy to omit.
    private static func byte(_ bytes: UnsafeRawBufferPointer, at offset: Int) -> UInt8? {
        guard bytes.indices.contains(offset) else { return nil }
        return bytes.load(fromByteOffset: offset, as: UInt8.self)
    }

    private static func skipGIFSubBlocks(_ bytes: UnsafeRawBufferPointer, offset: inout Int) -> Bool {
        while let blockSize = byte(bytes, at: offset).map(Int.init) {
            offset += 1
            guard blockSize > 0 else { return true }
            guard offset + blockSize <= bytes.count else { return false }
            offset += blockSize
        }
        return false
    }

    private static func matches(_ expected: [UInt8], in bytes: UnsafeRawBufferPointer, at offset: Int) -> Bool {
        guard offset >= 0, offset + expected.count <= bytes.count else { return false }
        return bytes[offset..<offset + expected.count].elementsEqual(expected)
    }

    private static func littleEndianUInt32(_ bytes: UnsafeRawBufferPointer, offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else { return 0 }
        return UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    private static func bigEndianUInt32(_ bytes: UnsafeRawBufferPointer, offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= bytes.count else { return 0 }
        return UInt32(bigEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
}

extension UIImage {
    public var hasAnimatedFrames: Bool {
        sd_isAnimated
    }

    public var animatedSourceData: Data? {
        // Prefer the original downloaded bytes so GIF/APNG/WebP keep their source format.
        if let data = (self as? SDAnimatedImageProvider)?.animatedImageData {
            return data
        }

        // `sd_imageData()` can preserve animated formats that SDWebImage knows how to export.
        if let data = sd_imageData(), data.animatedImagePasteboardType != nil {
            return data
        }

        guard hasAnimatedFrames else {
            return nil
        }

        // Last resort for generated animated UIImages that no longer carry source bytes.
        return sd_imageData(as: .webP, compressionQuality: 1, firstFrameOnly: false)
    }
}
