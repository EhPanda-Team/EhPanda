//
//  AnimatedImage_Extension.swift
//  EhPanda
//

import UIKit
import SDWebImage
import UniformTypeIdentifiers

private enum ImageDataSignature {
    static let jpeg: [UInt8] = [0xFF, 0xD8, 0xFF]
    static let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    static let gif = Array("GIF".utf8)
    static let riff = Array("RIFF".utf8)
    static let webp = Array("WEBP".utf8)
    static let apngAnimationControl = Array("acTL".utf8)
}

extension Data {
    var knownBinaryImageFileExtension: String? {
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

    var isKnownBinaryImageFormat: Bool {
        knownBinaryImageFileExtension != nil
    }

    var isJPEGFormat: Bool {
        starts(with: ImageDataSignature.jpeg)
    }

    var isPNGFormat: Bool {
        starts(with: ImageDataSignature.png)
    }

    var isAPNGFormat: Bool {
        isPNGFormat && range(of: Data(ImageDataSignature.apngAnimationControl)) != nil
    }

    var isGIFFormat: Bool {
        starts(with: ImageDataSignature.gif)
    }

    var isWebPFormat: Bool {
        starts(with: ImageDataSignature.riff)
            && hasBytes(ImageDataSignature.webp, at: 8)
    }

    var animatedImagePasteboardType: String? {
        if isWebPFormat {
            return UTType.webP.identifier
        }
        if isAPNGFormat {
            return UTType.png.identifier
        }
        if isGIFFormat {
            return UTType.gif.identifier
        }
        return nil
    }

    private func hasBytes(_ bytes: [UInt8], at offset: Int) -> Bool {
        guard count >= offset + bytes.count else { return false }
        let start = index(startIndex, offsetBy: offset)
        let end = index(start, offsetBy: bytes.count)
        return self[start..<end].elementsEqual(bytes)
    }
}

extension UIImage {
    var hasAnimatedFrames: Bool {
        sd_isAnimated
    }

    var animatedSourceData: Data? {
        // Prefer the original downloaded bytes so GIF/APNG/WebP keep their source format.
        if let data = (self as? SDAnimatedImageProvider)?.animatedImageData {
            return data
        }

        // `sd_imageData()` can preserve animated formats that SDWebImage knows how to export.
        let sdData = sd_imageData()
        if let data = sdData, data.animatedImagePasteboardType != nil {
            return data
        }

        guard hasAnimatedFrames else {
            return nil
        }

        // Last resort for generated animated UIImages that no longer carry source bytes.
        return sd_imageData(as: .webP, compressionQuality: 1, firstFrameOnly: false)
    }
}
