import Foundation

extension NotificationCenter {
  // 这个函数, 需要使用 await 来进行调用.
  // 不太理解. 这就是一个对象生成吧.
  func notifications(for name: Notification.Name) -> AsyncStream<Notification> {
    // 这里和 Notification 中, Publisher 的很像.
    // 但是这个怎么取消呢.
    AsyncStream<Notification> { continuation in
      NotificationCenter.default.addObserver(
        forName: name,
        object: nil,
        queue: nil
      ) { notification in
        continuation.yield(notification)
      }
    }
  }
}
