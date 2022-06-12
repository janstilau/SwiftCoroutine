import Foundation

/// The codable server status response.
struct ServerStatus: Codable {
  let activeUsers: Int
}

/// The codable message data model.
struct Message: Codable, Identifiable, Hashable {
  let id: UUID
  let user: String?
  let message: String
  var date: Date
}

// 在 Extension 里面, 提供简便方法. 
extension Message {
  init(message: String) {
    self.id = .init()
    self.date = .init()
    self.user = nil
    self.message = message
  }
}
