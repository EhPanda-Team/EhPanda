//
//  Common.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI
import AlamofireImage

class Common {
    
}

public func ePrint(_ error: Error) {
    print(error.localizedDescription)
}

public func ePrint(_ string: String) {
    print(string)
}

public func ePrint(_ string: String?) {
    print(string ?? "エラーの内容が解析できませんでした")
}

public func executeMainAsyncally(_ closure: @escaping (()->())) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

public func executeAsyncally(_ closure: @escaping (()->())) {
    DispatchQueue.global().async {
        closure()
    }
}

enum ImageScaleType {
    case cover
    case preview
}

final class ImageContainer: ObservableObject {
    @Published var image: SwiftUI.Image
    
    init(from resource: String, type: ImageScaleType, _ targetHeight: CGFloat) {
        if let uiImage = UIImage(named: "Placeholder") {
            image = ImageScaler.getScaledImage(uiImage: uiImage, targetHeight: targetHeight, type: type)
        } else {
            image = Image("Placeholder")
        }
        
        guard let url = URL(string: resource) else { return }
        
        let downloader = ImageDownloader()
        downloader.download(URLRequest(url: url), completion: { [weak self] (resp) in
            if case .success(let image) = resp.result {
                DispatchQueue.main.async {
                    self?.image = ImageScaler.getScaledImage(uiImage: image, targetHeight: targetHeight, type: type)
                }
            }
        })
    }
}

class ImageScaler {
    static func getScaledImage(uiImage: UIImage, targetHeight: CGFloat, type: ImageScaleType) -> SwiftUI.Image {
        let width = uiImage.size.width
        let height = uiImage.size.height
        let targetRatio_Cover: CGFloat = 14 / 22
        let targetRatio_Preview: CGFloat = 32 / 45
        
        var targetSize: CGSize {
            CGSize(width: targetHeight * targetRatio, height: targetHeight)
        }
        var targetRatio: CGFloat {
            switch type {
            case .cover:
                return targetRatio_Cover
            case .preview:
                return targetRatio_Preview
            }
        }
        
        if type == .preview {
            return Image(uiImage: uiImage.af.imageAspectScaled(toFill: targetSize))
        }
        
        if (width / height) - targetRatio < 0.2 {
            return Image(uiImage: uiImage.af.imageAspectScaled(toFill: targetSize))
        } else {
            return Image(uiImage: uiImage.af.imageAspectScaled(toFit: targetSize))
        }
    }
}
