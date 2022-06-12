import Foundation

extension InputStream {
  /// The avalable stream data.
  var data: Data {
    var data = Data()
    open()
    
    let maxLength = 1024
    // 有 alloc, 必须要有 deallocate.
    // 这里的, 从 stream 里面取值的思路, 其实和 C 风格的没有太多区别.
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxLength)
    while hasBytesAvailable {
      let read = read(buffer, maxLength: maxLength)
      guard read > 0 else { break }
      data.append(buffer, count: read)
    }
    buffer.deallocate()
    close()
    
    return data
  }
}
