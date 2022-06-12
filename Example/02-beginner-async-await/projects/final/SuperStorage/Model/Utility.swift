import Foundation

/// Easily throw generic errors with a text description.
extension String: LocalizedError {
  public var errorDescription: String? {
    return self
  }
}

// ByteCountFormatter 在 iOS 6.0 里面就出现了.
let sizeFormatter: ByteCountFormatter = {
  let formatter = ByteCountFormatter()
  formatter.allowedUnits = [.useMB]
  formatter.isAdaptive = true
  return formatter
}()

let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short
  return formatter
}()

extension URLRequest {
  init(url: URL, offset: Int, length: Int) {
    self.init(url: url)
    // 使用, Http 的 bytes 进行了对应的断点续传的功能. 
    addValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
  }
}
