import UIKit

actor ImageLoader: ObservableObject {
  enum DownloadState {
    case inProgress(Task<UIImage, Error>)
    case completed(UIImage)
    case failed
  }
  
  private(set) var cache: [String: DownloadState] = [:]
  
  func add(_ image: UIImage, forKey key: String) {
    cache[key] = .completed(image)
  }
  
  func image(_ serverPath: String) async throws -> UIImage {
    if let cached = cache[serverPath] {
      switch cached {
      case .completed(let image):
        return image
      case .inProgress(let task):
        return try await task.value
      case .failed: throw "Download failed"
      }
    }
    
    let download: Task<UIImage, Error> = Task.detached {
      guard let url = URL(string: "http://localhost:8080".appending(serverPath)) else {
        throw "Could not create the download URL"
      }
      print("Download: \(url.absoluteString)")
      let data = try await URLSession.shared.data(from: url).0
      return try resize(data, to: CGSize(width: 200, height: 200))
    }
    
    cache[serverPath] = .inProgress(download)
    
    do {
      let result = try await download.value
      add(result, forKey: serverPath)
      return result
    } catch {
      cache[serverPath] = .failed
      throw error
    }
  }
  
  func clear() {
    cache.removeAll()
  }
}
