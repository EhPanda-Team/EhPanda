//
//  ImageSaver.swift
//  ImageSaver
//
//  Created by 荒木辰造 on R 3/08/31.
//

import SwiftUI
import SwiftyBeaver

class ImageSaver: NSObject {
    @Binding var isSuccess: Bool?

    init(isSuccess: Binding<Bool?>) {
        _isSuccess = isSuccess
    }

    func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(
            image, self, #selector(didFinishSavingImage), nil
        )
    }
    @objc func didFinishSavingImage(
        _ image: UIImage,
        didFinishSavingWithError error: Error?,
        contextInfo: UnsafeRawPointer
    ) {
        isSuccess = error == nil
        if let error = error {
            SwiftyBeaver.error(error)
        }
    }
}
