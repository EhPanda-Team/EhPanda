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

final class ImageContainer: ObservableObject {
    @Published var image = Image("Placeholder")

    init(from resource: String, _ targetHeight: CGFloat) {
        guard let url = URL(string: resource) else { return }
        
        let downloader = ImageDownloader()
        downloader.download(URLRequest(url: url), completion: { [weak self] (resp) in
            if case .success(let image) = resp.result {
                DispatchQueue.main.async {
                    self?.image = ImageScaler.getScaledImage(uiImage: image, targetHeight: targetHeight)
                }
            }
        })
    }
}

class ImageScaler {
    static func getScaledImage(uiImage: UIImage, targetHeight: CGFloat) -> SwiftUI.Image {
        let width = uiImage.size.width
        let height = uiImage.size.height
        let targetRatio: CGFloat = 70 / 110
        let targetSize = CGSize(width: targetHeight * targetRatio, height: targetHeight)
        
        if (width / height) - targetRatio < 0.2 {
            return Image(uiImage: uiImage.af.imageAspectScaled(toFill: targetSize))
        } else {
            return Image(uiImage: uiImage.af.imageAspectScaled(toFit: targetSize))
        }
    }
}
