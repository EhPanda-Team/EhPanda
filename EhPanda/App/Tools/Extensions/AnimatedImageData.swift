//
//  AnimatedImageData.swift
//  EhPanda
//

import UIKit
import Kingfisher
import KingfisherWebP
import UniformTypeIdentifiers

extension Data {
    var animatedImagePasteboardType: String? {
        if isWebPFormat {
            return UTType.webP.identifier
        }
        if isGIFFormat {
            return UTType.gif.identifier
        }
        return nil
    }

    private var isGIFFormat: Bool {
        starts(with: [0x47, 0x49, 0x46])
    }
}

extension UIImage {
    var hasAnimatedFrames: Bool {
        (kf.imageFrameCount ?? images?.count ?? 1) > 1
    }

    var animatedSourceData: Data? {
        if let data = kf.frameSource?.data {
            return data
        }
        guard hasAnimatedFrames else {
            return nil
        }
        if let data = kf.data(format: .GIF) {
            return data
        }
        return kf.webpRepresentation()
    }
}
