import Foundation

class TimeoutTask<Success> {
  struct TimeoutError: LocalizedError {
    var errorDescription: String? {
      return "The operation timed out."
    }
  }
  
  let nanoseconds: UInt64
  let operation: @Sendable () async throws -> Success
  
  init(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> Success
  ) {
    self.nanoseconds = UInt64(seconds * 1_000_000_000)
    self.operation = operation
  }
  
  private var continuation: CheckedContinuation<Success, Error>?
  
  func cancel() {
    continuation?.resume(throwing: CancellationError())
    continuation = nil
  }
  // 使用, withCheckedThrowingContinuation 这种机制, 来暂停当前的线程.
  // withCheckedThrowingContinuation 应该是, 最直接的将我们的业务代码, 和协程暂停的机制, 联系起来的一种方式.
  // 就像是, Corrency.await 一样. 使用 Callback 的方式. 相比较而然, 这种续体的存在, 更加的简单. 
  var value: Success {
    get async throws {
      return try await
      
      withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        
        Task {
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
}
