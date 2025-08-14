//
//  ImagePipeline.swift
//  Havn
//
//  Created by Zac Seebeck on 8/12/25.
//


import SwiftUI
import CoreData
import ImageIO
import UIKit

final class ImagePipeline {
    static let shared = ImagePipeline()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 200 } // ~200 images (tune as needed)

    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }

    func store(_ img: UIImage, forKey key: String) {
        cache.setObject(img, forKey: key as NSString)
    }

    func downsampledImage(from data: Data,
                          maxDimension: CGFloat = UIScreen.main.nativeBounds.height,
                          scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let options: [NSString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard
            let src = CGImageSourceCreateWithData(data as CFData, nil),
            let cg  = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}