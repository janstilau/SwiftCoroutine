import UIKit

actor ImageLoader: ObservableObject {
  
  enum DownloadState {
    // 直接, 存储的是 Task.
    case inProgress(Task<UIImage, Error>)
    case completed(UIImage)
    case failed
  }
  
  private(set) var cache: [String: DownloadState] = [:]
  
  func add(_ image: UIImage, forKey key: String) {
    cache[key] = .completed(image)
  }
  
  // 使用这种方式, 来触发下载的操作.
  func image(_ serverPath: String) async throws -> UIImage {
    if let cached = cache[serverPath] {
      switch cached {
      case .completed(let image):
        return image
      case .inProgress(let task):
        // 这里进行了 await.
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
      // 在这里, 等待 task 的结果, 然后加入到缓存中. 
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
