import Foundation

extension NotificationCenter {
  func notifications(for name: Notification.Name) -> AsyncStream<Notification> {
    // 既然, withContinuation 里面, 可以将系统创建好的续体存起来, 在创建 AsyncStream 的时候, 也可以将系统创建好的续体存起来.
    // 这样, 外界其实就有机会来进行数据的创建了.
    // 其实, 也不会有太多的状态管理问题.
    // 续体, 如果不调用, 对应的协程是不会被 resume 的. 所以, 如果能够保存存储的续体, 在合适的时间触发协程的 finish, 就没有太大问题. 
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
