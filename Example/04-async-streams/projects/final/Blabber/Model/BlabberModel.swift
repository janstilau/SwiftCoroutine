import Foundation
import CoreLocation
import Combine
import UIKit

// The app model that communicates with the server.
class BlabberModel: ObservableObject {
  var loginUser = ""
  var urlSession = URLSession.shared
  
  init() { }
  
  /// Current live updates
  @Published var messages: [Message] = []
  
  /// Shares the current user's address in chat.
  func shareLocation() async throws { }
  
  /// Does a countdown and sends the message.
  func countdown(to message: String) async throws {
    guard !message.isEmpty else { return }
    
    /*
     An asynchronous sequence generated from a closure that calls a continuation to produce new elements.

     struct AsyncStream<Element>

     AsyncStream conforms to AsyncSequence, providing a convenient way to create an asynchronous sequence without manually implementing an asynchronous iterator. In particular, an asynchronous stream is well-suited to adapt callback- or delegation-based APIs to participate with async-await.
     You initialize an AsyncStream with a closure that receives an AsyncStream.Continuation.
     Produce elements in this closure, then provide them to the stream by calling the continuation’s yield(_:) method.
     When there are no further elements to produce, call the continuation’s finish() method. This causes the sequence iterator to produce a nil, which terminates the sequence. The continuation conforms to Sendable, which permits calling it from concurrent contexts external to the iteration of the AsyncStream.
     An arbitrary source of elements can produce elements faster than they are consumed by a caller iterating over them. Because of this, AsyncStream defines a buffering behavior, allowing the stream to buffer a specific number of oldest or newest elements. By default, the buffer limit is Int.max, which means the value is unbounded.
     */
    let counter = AsyncStream<String> { continuation in
      var countdown = 3
      Timer.scheduledTimer(
        withTimeInterval: 1.0,
        repeats: true
      ) { timer in
        guard countdown > 0 else {
          timer.invalidate()
          // yield with result, 会在输出最后的一个值后, 进行 Finish 的操作.
          continuation.yield(with: .success("🎉 " + message))
          return
        }
        
        continuation.yield("\(countdown) ...")
        countdown -= 1
      }
    }
    
    try await counter.forEach {
      try await self.say($0)
    }
  }
  
  /// Start live chat updates
  @MainActor
  func startChat() async throws {
    guard
      let query = loginUser.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let url = URL(string: "http://localhost:8080/chat/room?\(query)")
    else {
      throw "Invalid username"
    }
    
    let (stream, response) = try await liveURLSession.bytes(from: url, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    print("Start live updates")
    
    /*
     Summary

     Execute an operation with a cancellation handler that’s immediately invoked if the current task is canceled.
     Declaration

     func withTaskCancellationHandler<T>(handler: @Sendable () -> Void,
                                    operation: () async throws -> T) async rethrows -> T
     This differs from the operation cooperatively checking for cancellation and reacting to it in that the cancellation handler is always and immediately invoked when the task is canceled. For example, even if the operation is running code that never checks for cancellation, a cancellation handler still runs and provides a chance to run some cleanup code.
     Doesn’t check for cancellation, and always executes the passed operation.
     This function returns immediately and never suspends.

     */
    // withTaskCancellationHandler 中, 用来添加当 Task 取消的时候, 应该触发的逻辑.
    try await withTaskCancellationHandler {
      print("End live updates")
      messages = []
    } operation: {
      try await readMessages(stream: stream)
    }
  }
  
  /// Reads the server chat stream and updates the data model.
  @MainActor
  private func readMessages(stream: URLSession.AsyncBytes) async throws {
    var iterator = stream.lines.makeAsyncIterator()
    
    guard let first = try await iterator.next() else {
      throw "No response from server"
    }
    // 第一个字节, 会是在线人数.
    guard let data = first.data(using: .utf8),
          let status = try? JSONDecoder()
      .decode(ServerStatus.self, from: data) else {
      throw "Invalid response from server"
    }
    
    messages.append(
      Message(
        message: "\(status.activeUsers) active users"
      )
    )
    
    let notifications = Task {
      await startObserveAppStatus()
    }
    
    // 当, 任务推出的时候, 进行 Task 的取消.
    // 这里有点问题啊, 为什么 notifications 的取消动作, 可以影响到里面生成的 Task.
    defer {
      notifications.cancel()
    }
    
    for try await line in stream.lines {
      if let data = line.data(using: .utf8),
         let update = try? JSONDecoder().decode(Message.self, from: data) {
        messages.append(update)
      }
    }
  }
  
  // 发送聊天消息, 到服务器端.
  func say(_ text: String, isSystemMessage: Bool = false) async throws {
    guard
      !text.isEmpty,
      let url = URL(string: "http://localhost:8080/chat/say")
    else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(
      Message(id: UUID(), user: isSystemMessage ? nil : loginUser, message: text, date: Date())
    )
    
    let (_, response) = try await urlSession.data(for: request, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
  }
  
  // 在这开启了两个异步任务, 进行前后台切换的监听.
  func startObserveAppStatus() async {
    // 这两个任务, 不会随着外层 Task cancel 进行取消.
    // 所以这里有 Bug. 使用 Task 开启的新的异步上下文, 然后里面使用 for 来监听了一个无限序列, 导致的问题就是, 这里的监听, 其实是永远不会结束的.
    Task {
      for await _ in await NotificationCenter.default
        .notifications(for: UIApplication.willResignActiveNotification) {
        // 每当一个通知发出之后, 进行对应的服务器请求.
        try? await say("\(loginUser) went away", isSystemMessage: true)
      }
    }
    
    Task {
      for await _ in await NotificationCenter.default
        .notifications(for: UIApplication.didBecomeActiveNotification) {
        try? await say("\(loginUser) came back", isSystemMessage: true)
      }
    }
  }
  
  /// A URL session that goes on indefinitely, receiving live updates.
  private var liveURLSession: URLSession = {
    var configuration = URLSessionConfiguration.default
    // 在这里, 将超时时间, 设置到无限大.
    configuration.timeoutIntervalForRequest = .infinity
    return URLSession(configuration: configuration)
  }()
}

extension AsyncSequence {
  // 这不是一个 Container, 仅仅是一个方法, 用来封装 forin 的逻辑. 
  func forEach(_ body: (Element) async throws -> Void) async throws {
    for try await element in self {
      try await body(element)
    }
  }
}
