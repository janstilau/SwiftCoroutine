import Foundation

extension Notification.Name {
  static let response = Notification.Name("response")
  static let connected = Notification.Name("connected")
  static let disconnected = Notification.Name("disconnected")
}

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

actor UnreliableAPI {
  var counter = 0
  
  // 这是一个同步函数. 但是, 这是一个 actor, 所以在外界调用的时候, 这是一个异步函数. 
  func action(failingEvery: Int) throws {
    counter += 1
    if counter % failingEvery == 0 {
      counter = 0
      throw Error()
    }
  }
}

extension UnreliableAPI {
  struct Error: LocalizedError {
    var errorDescription: String? {
      return "UnreliableAPI.action(failingEvery:) failed."
    }
  }
  
  static let shared = UnreliableAPI()
}
