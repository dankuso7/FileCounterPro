import Foundation
import CoreLocation
import ImageIO
import AVFoundation

func extractImageLocation(url: URL) -> CLLocationCoordinate2D? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        print("Failed to create CGImageSource")
        return nil
    }
    
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        print("Failed to copy properties")
        return nil
    }
    
    print("Properties keys: \(properties.keys.map { $0 as String })")
    
    guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
        print("No GPS dictionary found")
        return nil
    }
    
    print("GPS Dictionary: \(gps)")
    
    guard let latNum = gps[kCGImagePropertyGPSLatitude] as? NSNumber,
          let lonNum = gps[kCGImagePropertyGPSLongitude] as? NSNumber,
          let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
          let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String else {
        print("Missing GPS fields")
        return nil
    }
    
    let lat = latNum.doubleValue
    let lon = lonNum.doubleValue
    
    let finalLat = latRef == "N" ? lat : -lat
    let finalLon = lonRef == "E" ? lon : -lon
    
    return CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon)
}

// create a dummy image with GPS
let imageURL = URL(fileURLWithPath: "test_gps.jpg")
let imageDest = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.jpeg" as CFString, 1, nil)!

let gpsDict: [CFString: Any] = [
    kCGImagePropertyGPSLatitude: 37.7749,
    kCGImagePropertyGPSLongitude: 122.4194,
    kCGImagePropertyGPSLatitudeRef: "N",
    kCGImagePropertyGPSLongitudeRef: "W"
]
let properties: [CFString: Any] = [
    kCGImagePropertyGPSDictionary: gpsDict
]

// create dummy pixel data
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8, bytesPerRow: 40, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let image = context.makeImage()!

CGImageDestinationAddImage(imageDest, image, properties as CFDictionary)
CGImageDestinationFinalize(imageDest)

print("Created test image at \(imageURL.path)")

if let loc = extractImageLocation(url: imageURL) {
    print("Extracted: \(loc.latitude), \(loc.longitude)")
} else {
    print("Failed to extract")
}

