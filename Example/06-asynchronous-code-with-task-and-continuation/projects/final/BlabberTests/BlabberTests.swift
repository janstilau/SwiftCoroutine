import XCTest
@testable import Blabber

class BlabberTests: XCTestCase {
  let model: BlabberModel = {
    let model = BlabberModel()
    model.username = "test"
    
    let testConfiguration = URLSessionConfiguration.default
    testConfiguration.protocolClasses = [TestURLProtocol.self]
    
    model.urlSession = URLSession(configuration: testConfiguration)
    model.sleep = { try await Task.sleep(nanoseconds: $0 / 1_000_000_000) }
    return model
  }()
  
  func testModelSay() async throws {
    try await model.say("Hello!")
    /*
     Summary
     Asserts that an expression is not nil, and returns the unwrapped value.
     Declaration

     func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?,
     _ message: @autoclosure () -> String = "",
     file: StaticString = #filePath,
     line: UInt = #line) throws -> T
     Discussion

     This function generates a failure when expression is nil. Otherwise, it returns the unwrapped value of expression for subsequent use in the test.
     Parameters

     expression
     An expression of type T?. The expression’s type determines the type of the return value.
     message
     An optional description of a failure.
     file
     The file where the failure occurs. The default is the filename of the test case where you call this function.
     line
     The line number where the failure occurs. The default is the line number where you call this function.
     Returns

     The result of evaluating and unwrapping the expression, which is of type T. XCTUnwrap() only returns a value if expression is not nil.
     */
    let request = try XCTUnwrap(TestURLProtocol.lastRequest)
    
    XCTAssertEqual(
      request.url?.absoluteString,
      "http://localhost:8080/chat/say"
    )
    
    let httpBody = try XCTUnwrap(request.httpBody)
    let message = try XCTUnwrap(try? JSONDecoder()
      .decode(Message.self, from: httpBody))
    
    XCTAssertEqual(message.message, "Hello!")
  }
  
  func testModelCountdown() async throws {
    async let countdown: Void = model.countdown(to: "Tada!")
    async let messages = TimeoutTask(seconds: 10) {
      // 注意, 这里并不是, 将 Response 里面的 data 抽取出来, 当做 asyncStream 的 element, 而是从 Request 里面进行读取的. 
      await TestURLProtocol.requests
        .prefix(4)
        .compactMap(\.httpBody)
        .compactMap { data in
          try? JSONDecoder()
            .decode(Message.self, from: data).message
        }
        .reduce(into: []) { result, request in
          result.append(request)
        }
      // Sequence 进行到 Reduce , 最终会变为一个值
    }.value
    
    let (messagesResult, _) = try await (messages, countdown)
    
    XCTAssertEqual(
      ["3...", "2...", "1...", "🎉 Tada!"],
      messagesResult
    )
  }
}
