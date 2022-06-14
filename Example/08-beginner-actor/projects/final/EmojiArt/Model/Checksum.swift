import Foundation

enum Checksum {
  static var cnt = 0
  // 假实现, 就是睡眠了一段时间. 
  static func verify(_ checksum: String) async throws {
    let duration = Double.random(in: 0.5...2.5)
    await Task.sleep(seconds: duration)
  }
}
