import Foundation

// A catch-all URL protocol that returns successful response and records all requests.
// 要看懂这个, 要完全理解一些 URLProtocol 这个类的运转机制才可以.
class TestURLProtocol: URLProtocol {
  
  // 每当, 进行了一次新的网络请求之后, 这个值都会被重新设置. 
  static var lastRequest: URLRequest? {
    didSet {
      if let request = lastRequest {
        continuation?.yield(request)
      }
    }
  }
  
  static private var continuation: AsyncStream<URLRequest>.Continuation?
  
  /*
   从这里来看, 续体的使用就是存一起, 然后在合适的时机, 触发. 其实和 Callback 没有任何的区别.
   仅仅是续体这个东西, 是一个新的概念, 它的 resume 的机制, 也和直接的函数调用, 没有太大的关系.
   */
  static var requests: AsyncStream<URLRequest> = {
    /*
     AsyncStream 的内部, 其实是有一个 FifoQueue 做 Buffer 的, 所以实际上, continuation 的 resume 所做的, 就是给 Buffer 存值, 并且进行协程唤醒的操作.
     将 continuation 存起来, 之后调用, 同样会操作到 AsyncStream 的内部. 
     */
    AsyncStream { continuation in
      TestURLProtocol.continuation = continuation
    }
  }()
  
  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }
  
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }
  
  /// Store the URL request and send success response back to the client.
  override func startLoading() {
    guard let client = client,
          let url = request.url,
          let response = HTTPURLResponse(url: url,
                                         statusCode: 200,
                                         httpVersion: nil,
                                         headerFields: nil) else {
      fatalError("Client or URL missing")
    }
    
    client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client.urlProtocol(self, didLoad: Data())
    client.urlProtocolDidFinishLoading(self)
    
    guard let stream = request.httpBodyStream else {
      fatalError("Unexpected test scenario")
    }
    
    var request = request
    request.httpBody = stream.data
    // 每次, 在进行一个新的网络请求的时候, 都会更新一下 lastRequest 的值.
    Self.lastRequest = request
  }
  
  override func stopLoading() {
  }
}
