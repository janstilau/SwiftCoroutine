import Foundation

enum Checksum {
  static var cnt = 0
  static func verify(_ checksum: String) async throws {
    let duration = Double.random(in: 0.5...2.5)
    await Task.sleep(seconds: duration)
  }
}
