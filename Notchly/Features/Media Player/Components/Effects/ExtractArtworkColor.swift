//
//  ExtractArtworkColor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import AppKit
import CoreImage

// MARK: - NSImage Extension

extension NSImage {
    /// Returns the average (dominant) color of the image using the CIAreaAverage Core Image filter.
    /// This is useful for extracting a background glow or theme color from album artwork.
    func dominantColor() -> NSColor? {
        /// Convert image to TIFF representation and Core Image-compatible format
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmap) else {
            return nil
        }

        /// Define the area of the image to analyze (entire image)
        let extentVector = CIVector(
            x: ciImage.extent.origin.x,
            y: ciImage.extent.origin.y,
            z: ciImage.extent.size.width,
            w: ciImage.extent.size.height
        )

        /// Create the CIAreaAverage filter
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: extentVector
            ]
        ) else {
            return nil
        }

        /// Get filtered output image (should be a 1x1 pixel)
        guard let outputImage = filter.outputImage else {
            return nil
        }

        /// Render the image to extract RGBA pixel data
        var bitmapData = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: nil)
        context.render(
            outputImage,
            toBitmap: &bitmapData,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        /// Convert raw bytes to NSColor
        return NSColor(
            red: CGFloat(bitmapData[0]) / 255.0,
            green: CGFloat(bitmapData[1]) / 255.0,
            blue: CGFloat(bitmapData[2]) / 255.0,
            alpha: CGFloat(bitmapData[3]) / 255.0
        )
    }
}

// MARK: - NSColor Extension

extension NSColor {
    /// Returns a more vibrant version of the color by increasing its saturation.
    /// - Parameter factor: The multiplier to apply to the current saturation. Clamped to a maximum of 1.0.
    func vibrantColor(factor: CGFloat = 1.5) -> NSColor? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        /// Extract HSBA components
        guard ((self.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)) != nil) == true else {
            return nil
        }

        /// Increase saturation but cap it at 1.0
        let newSaturation = min(saturation * factor, 1.0)
        return NSColor(
            calibratedHue: hue,
            saturation: newSaturation,
            brightness: brightness,
            alpha: alpha
        )
    }
}
