import UIKit
import Accelerate

/// Easily throw generic errors with a text description.
extension String: LocalizedError {
  public var errorDescription: String? {
    return self
  }
}

extension Task where Success == Never, Failure == Never {
  /// Suspends the current task for at least the given duration in seconds.
  /// - Parameter seconds: The sleep duration in seconds.
  static func sleep(seconds: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
  }
}

struct ResizeError: Error { }

func resize(_ data: Data, to size: CGSize) throws -> UIImage {
  guard let cgImage = UIImage(data: data)?.cgImage,
        let colorSpace = cgImage.colorSpace else {
    throw ResizeError()
  }
  
  var format = vImage_CGImageFormat(
    bitsPerComponent: UInt32(cgImage.bitsPerComponent),
    bitsPerPixel: UInt32(cgImage.bitsPerPixel),
    colorSpace: Unmanaged.passRetained(colorSpace),
    bitmapInfo: cgImage.bitmapInfo,
    version: 0,
    decode: nil,
    renderingIntent: cgImage.renderingIntent
  )
  
  var buffer = vImage_Buffer()
  vImageBuffer_InitWithCGImage(&buffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
  
  var destinationBuffer = try vImage_Buffer(width: Int(200), height: Int(200), bitsPerPixel: format.bitsPerPixel)
  
  defer { destinationBuffer.free() }
  
  _ = withUnsafePointer(to: buffer) { sourcePointer in
    vImageScale_ARGB8888(sourcePointer, &destinationBuffer, nil, vImage_Flags(kvImageNoFlags))
  }
  
  let destinationCGImage = vImageCreateCGImageFromBuffer(
    &buffer, &format, nil, nil, vImage_Flags(kvImageNoFlags), nil
  )
  
  guard let destinationCGImage = destinationCGImage else {
    throw ResizeError()
  }
  
  return UIImage(cgImage: destinationCGImage.takeRetainedValue())
}
