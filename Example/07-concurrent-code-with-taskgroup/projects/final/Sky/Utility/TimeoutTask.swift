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
