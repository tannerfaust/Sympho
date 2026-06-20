//
//  PlatformImage.swift
//  Sympho
//
//  Cross-platform image plumbing so Library/Home thumbnails and file previews
//  render identically on macOS (AppKit) and iOS (UIKit).
//

import SwiftUI
import ImageIO
import QuickLookThumbnailing

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

extension Image {
    /// Builds a SwiftUI `Image` from the platform-native image type.
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

enum PlatformScreen {
    /// Backing scale used when requesting Quick Look thumbnails.
    static var scale: CGFloat {
        #if os(macOS)
        return NSScreen.main?.backingScaleFactor ?? 2
        #else
        let displayScale = UITraitCollection.current.displayScale
        return displayScale > 0 ? displayScale : 2
        #endif
    }
}

extension PlatformImage {
    /// Rough byte estimate used as an `NSCache` cost.
    var cacheCost: Int {
        #if os(macOS)
        return Int(size.width * size.height * 4)
        #else
        return Int(size.width * scale * size.height * scale * 4)
        #endif
    }

    static func from(cgImage: CGImage) -> PlatformImage {
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
}

extension QLThumbnailRepresentation {
    var platformImage: PlatformImage {
        #if os(macOS)
        return nsImage
        #else
        return uiImage
        #endif
    }
}

/// High-quality, low-memory downsample using ImageIO. Identical on both
/// platforms and lighter than drawing through AppKit/UIKit image contexts.
func symphoDownsampledImage(data: Data, maxPixelSize: CGFloat) -> PlatformImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
        return PlatformImage(data: data)
    }

    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: Int(maxPixelSize)
    ] as CFDictionary

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
        return PlatformImage(data: data)
    }

    return PlatformImage.from(cgImage: cgImage)
}
