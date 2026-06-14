import Foundation
import CoreLocation
import ImageIO

func extract(url: URL) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        print("no source")
        return
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        print("no properties")
        return
    }
    
    // Print all keys
    print("Keys: \(properties.keys.map { $0 as String })")
    
    guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
        print("no gps dict")
        return
    }
    print("GPS dict: \(gps)")
}

// Just checking if syntax is right
print("Syntax OK")
