import Foundation

class TimeoutTask<Success> {
  let nanoseconds: UInt64
  let operation: @Sendable () async throws -> Success
  
  private var continuation: CheckedContinuation<Success, Error>?
  
  var value: Success {
    get async throws {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        
        Task {
          // 如果, 到了固定的事件, 还没有完成, 就报错.
          // 这是一个带有超时机制的类. 
          try await Task.sleep(nanoseconds: nanoseconds)
          self.continuation?.resume(throwing: TimeoutError())
          self.continuation = nil
        }
        
        Task {
          let result = try await operation()
          self.continuation?.resume(returning: result)
          self.continuation = nil
        }
      }
    }
  }
  
  // 在这个类里面, 之所以将 continuation 存储起来, 就是为了 cancel
  func cancel() {
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
  
  init(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> Success
  ) {
    self.nanoseconds = UInt64(seconds * 1_000_000_000)
    self.operation = operation
  }
}

extension TimeoutTask {
  struct TimeoutError: LocalizedError {
    var errorDescription: String? {
      return "The operation timed out."
    }
  }
}
