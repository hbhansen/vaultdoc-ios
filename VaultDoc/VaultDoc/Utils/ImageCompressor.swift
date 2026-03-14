@preconcurrency import UIKit
import ImageIO

struct ImageCompressor {
    nonisolated static func compress(
        _ image: UIImage,
        quality: CGFloat = 0.8,
        maxDimension: CGFloat = 2_048
    ) -> Data? {
        let preparedImage: UIImage
        let longestSide = max(image.size.width, image.size.height)

        if longestSide > maxDimension {
            preparedImage = thumbnail(image, maxDimension: maxDimension)
        } else {
            preparedImage = image
        }

        return preparedImage.jpegData(compressionQuality: quality)
    }

    nonisolated static func thumbnail(_ image: UIImage, maxDimension: CGFloat = 200) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    nonisolated static func downsampledImage(
        data: Data,
        maxDimension: CGFloat,
        scale: CGFloat = 1
    ) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension * scale
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
