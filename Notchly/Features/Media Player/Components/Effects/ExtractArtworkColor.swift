//
//  ExtractArtworkColor.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import AppKit
import CoreImage

extension NSImage {
    /// Returns the average color of the image using the CIAreaAverage filter.
    func dominantColor() -> NSColor? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmap) else {
            return nil
        }
        
        let extentVector = CIVector(x: ciImage.extent.origin.x,
                                    y: ciImage.extent.origin.y,
                                    z: ciImage.extent.size.width,
                                    w: ciImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: extentVector
        ]) else {
            return nil
        }
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        /// Render to a 1x1 pixel to get the average.
        var bitmapData = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: nil)
        context.render(outputImage,
                       toBitmap: &bitmapData,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return NSColor(red: CGFloat(bitmapData[0]) / 255.0,
                       green: CGFloat(bitmapData[1]) / 255.0,
                       blue: CGFloat(bitmapData[2]) / 255.0,
                       alpha: CGFloat(bitmapData[3]) / 255.0)
    }
}

extension NSColor {
    /// Returns a version of the color with increased saturation (up to 1.0).
    func vibrantColor(factor: CGFloat = 1.5) -> NSColor? {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard ((self.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)) != nil) == true else {
            return nil
        }
        let newSaturation = min(saturation * factor, 1.0)
        return NSColor(calibratedHue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
    }
}
