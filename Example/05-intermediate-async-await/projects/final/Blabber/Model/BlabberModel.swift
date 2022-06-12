import Foundation
import CoreLocation
import Combine
import UIKit

/// The app model that communicates with the server.
class BlabberModel: ObservableObject {
  var username = ""
  var urlSession = URLSession.shared
  
  init() { }
  
  /// Current live updates
  @Published var messages: [Message] = []
  
  /// A chat location delegate
  private var delegate: ChatLocationDelegate?
  
  /// Shares the current user's address in chat.
  func shareLocation() async throws {
    // 实际上, 还是使用原有的 API 进行真正的业务操作.
    // 当调用 withCheckedThrowingContinuation 的时候, 其实是将当前的 Task 进行了 Suspend,
    // 然后调用传入的 body, 在 body 里面, 开启异步函数, 在异步函数的最后, 进行 resume 的操作.
    /*
     Suspends the current task, then calls the given closure with a checked throwing continuation for the current task.

     func withCheckedThrowingContinuation<T>(function: String = #function, _ body: (CheckedContinuation<T, Error>) -> Void) async throws -> T

     If resume(throwing:) is called on the continuation, this function throws that error.

     function
     A string identifying the declaration that is the notional source for the continuation, used to identify the continuation in runtime diagnostics related to misuse of this continuation.
     body
     A closure that takes an UnsafeContinuation parameter. You must resume the continuation exactly once.
     */
    
    // 这里的实现, 可以用 SwiftCoroutine 中的 wait 实现来进行理解.
    // 续体, 把其中 CompeltionHandler 取值, 并且 resume 的操作, 封装到了内部. 
    let location: CLLocation = try await
    withCheckedThrowingContinuation { [weak self] continuation in
      self?.delegate = ChatLocationDelegate(continuation: continuation)
    }
    
    print(location.description)
    
    let address: String = try await
    withCheckedThrowingContinuation { continuation in
      // 只要 continuation 可以出发就可以了. 至于到底是用异步函数, CompletionHandler, 还是 Delegate, 其实都不是太重要的事情.
      AddressEncoder.addressFor(location: location) { address, error in
        switch (address, error) {
        case (nil, let error?):
          continuation.resume(throwing: error)
        case (let address?, nil):
          continuation.resume(returning: address)
        case (nil, nil):
          continuation.resume(throwing: "Address encoding failed")
        case let (address?, error?):
          continuation.resume(returning: address)
          print(error)
        }
      }
    }
    
    try await say("📍 \(address)")
  }
  
  /// Does a countdown and sends the message.
  func countdown(to message: String) async throws {
    guard !message.isEmpty else { return }
    var countdown = 3
    let counter = AsyncStream<String> {
      do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
      } catch {
        return nil
      }
      
      defer { countdown -= 1 }
      
      switch countdown {
      case (1...): return "\(countdown)..."
      case 0: return "🎉 " + message
      default: return nil
      }
    }
    
    try await counter.forEach { [weak self] in
      try await self?.say($0)
    }
  }
  
  /// Start live chat updates
  @MainActor
  func chat() async throws {
    guard
      let query = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let url = URL(string: "http://localhost:8080/chat/room?\(query)")
    else {
      throw "Invalid username"
    }
    
    let (stream, response) = try await liveURLSession.bytes(from: url, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    print("Start live updates")
    
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
      await observeAppStatus()
    }
    
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
  
  /// Sends the user's message to the chat server
  func say(_ text: String, isSystemMessage: Bool = false) async throws {
    guard
      !text.isEmpty,
      let url = URL(string: "http://localhost:8080/chat/say")
    else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try JSONEncoder().encode(
      Message(id: UUID(), user: isSystemMessage ? nil : username, message: text, date: Date())
    )
    
    let (_, response) = try await urlSession.data(for: request, delegate: nil)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
  }
  
  func observeAppStatus() async {
    Task {
      for await _ in await NotificationCenter.default
        .notifications(for: UIApplication.willResignActiveNotification) {
        try? await say("\(username) went away", isSystemMessage: true)
      }
    }
    
    Task {
      for await _ in await NotificationCenter.default
        .notifications(for: UIApplication.didBecomeActiveNotification) {
        try? await say("\(username) came back", isSystemMessage: true)
      }
    }
  }
  
  /// A URL session that goes on indefinitely, receiving live updates.
  private var liveURLSession: URLSession = {
    var configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = .infinity
    return URLSession(configuration: configuration)
  }()
}

extension AsyncSequence {
  func forEach(_ body: (Element) async throws -> Void) async throws {
    for try await element in self {
      try await body(element)
    }
  }
}
