//
//  PreviewImageView.swift
//  EhPanda
//

import SwiftUI
import ImageIO
import Kingfisher

struct PreviewImageView: View {
    private let originalURL: URL?
    private let maxPixelSize: CGFloat
    private static let defaultMaxPixelSize = Defaults.ImageSize.previewMaxW * 3

    init(
        originalURL: URL?,
        maxPixelSize: CGFloat = PreviewImageView.defaultMaxPixelSize
    ) {
        self.originalURL = originalURL
        self.maxPixelSize = maxPixelSize
    }

    var body: some View {
        if let originalURL, originalURL.isFileURL {
            LocalPreviewImageView(fileURL: originalURL, maxPixelSize: maxPixelSize) {
                Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect))
            }
        } else {
            let (url, modifier) = PreviewResolver.getPreviewConfigs(originalURL: originalURL)
            KFImage.url(
                url,
                cacheKey: url?.stableImageCacheKey
                    ?? originalURL?.stableImageCacheKey
                    ?? originalURL?.absoluteString
            )
            .placeholder {
                Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect))
            }
            .imageModifier(modifier)
            .fade(duration: 0.25)
            .resizable()
            .scaledToFit()
        }
    }
}

private struct LocalPreviewImageView<Placeholder: View>: View {
    private let fileURL: URL
    private let maxPixelSize: CGFloat
    private let placeholder: Placeholder

    @State private var thumbnail: UIImage?

    init(
        fileURL: URL,
        maxPixelSize: CGFloat,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.fileURL = fileURL
        self.maxPixelSize = maxPixelSize
        self.placeholder = placeholder()
    }

    private var cacheKey: String {
        let resourceValues = try? fileURL.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey
        ])
        let modificationStamp = resourceValues?.contentModificationDate?
            .timeIntervalSinceReferenceDate ?? .zero
        let fileSize = resourceValues?.fileSize ?? 0
        return "\(fileURL.path)#\(Int(maxPixelSize))#\(fileSize)#\(modificationStamp)"
    }

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 5,
                            style: .continuous
                        )
                    )
            } else {
                placeholder
            }
        }
        .task(id: cacheKey) {
            await loadThumbnail()
        }
    }

    @MainActor
    private func loadThumbnail() async {
        if let cachedThumbnail = LocalPreviewThumbnailCache.shared.image(forKey: cacheKey) {
            thumbnail = cachedThumbnail
            return
        }

        let fileURL = fileURL
        let maxPixelSize = maxPixelSize
        let generatedThumbnail = await Task.detached(priority: .utility) {
            Self.makeThumbnail(fileURL: fileURL, maxPixelSize: maxPixelSize)
        }
        .value

        if let generatedThumbnail {
            LocalPreviewThumbnailCache.shared.store(generatedThumbnail, forKey: cacheKey)
        }
        thumbnail = generatedThumbnail
    }

    nonisolated private static func makeThumbnail(fileURL: URL, maxPixelSize: CGFloat) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(Int(maxPixelSize.rounded(.up)), 1)
        ]

        guard let imageRef = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            .zero,
            options as CFDictionary
        ) else {
            return nil
        }

        return UIImage(cgImage: imageRef)
    }
}

private final class LocalPreviewThumbnailCache {
    static let shared = LocalPreviewThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
