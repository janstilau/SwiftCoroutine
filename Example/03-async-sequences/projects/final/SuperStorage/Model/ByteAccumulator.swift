import Foundation

/// Type that accumulates incoming data into an array of bytes.
class ByteAccumulator: CustomStringConvertible {
  private var offset = 0
  private var counter = -1
  private let name: String
  private let size: Int
  private let chunkCount: Int
  private var bytes: [UInt8]
  
  var data: Data { return Data(bytes[0..<offset]) }
  
  /// Creates a named byte accumulator.
  init(name: String, size: Int) {
    self.name = name
    self.size = size
    chunkCount = max(Int(Double(size) / 20), 1)
    bytes = [UInt8](repeating: 0, count: size)
  }
  
  /// Appends a byte to the accumulator.
  func append(_ byte: UInt8) {
    bytes[offset] = byte
    // 每次收集数据之后, 进行值的增加.
    counter += 1
    offset += 1
  }
  
  /// `true` if the current batch is filled with bytes.
  // 不断地进行数据的收集, 同时进行 counter 的修改.
  // 如果超过了某个阈值, 才进行后续的工作.
  // 这就是这个类最大的作用. 
  var isBatchCompleted: Bool {
    return counter >= chunkCount
  }
  
  /*
   这里的实现, 真实令人作呕.
   明明和 FullSize 进行判断就可以了.
   
   在判断之后, 进行 counter == 0 的赋值动作, 这样, 下一次进来如果还是 0, 那就是在这次循环里面, 没有进行真正的数据收集工作.
   这种写法, 无缘无故增加了复杂度.
   */
  func checkCompleted() -> Bool {
    defer { counter = 0 }
    return counter == 0
  }
  
  var progress: Double {
    Double(offset) / Double(size)
  }
  
  var description: String {
    "[\(name)] \(sizeFormatter.string(fromByteCount: Int64(offset)))"
  }
}
