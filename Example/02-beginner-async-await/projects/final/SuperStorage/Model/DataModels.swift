import Foundation

/// A downloadble file.
struct DownloadFile: Codable, Identifiable, Equatable {
  // 因为遵循了 Identifiable 这个 protocol, 所以一定要有一个 id 属性.
  var id: String { return name }
  let name: String
  let size: Int
  let date: Date
  
  static let empty = DownloadFile(name: "", size: 0, date: Date())
}

/// Download information for a given file.
struct DownloadInfo: Identifiable, Equatable {
  let id: UUID
  let name: String
  var progress: Double // 在下载的过程中, 会更新这个值. 然后, 这个值的改变, 会触发 View 的更新. 
}
