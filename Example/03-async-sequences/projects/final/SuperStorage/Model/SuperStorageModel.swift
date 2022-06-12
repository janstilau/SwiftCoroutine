import Foundation

/// The download model.
class SuperStorageModel: ObservableObject {
  /// The list of currently running downloads.
  @Published var downloads: [DownloadInfo] = []
  /*
   TaskLocal
   
   Property wrapper that defines a task-local value key.
   Declaration
   
   @propertyWrapper final class TaskLocal<Value> where Value : Sendable
   Discussion
   
   A task-local value is a value that can be bound and read in the context of a Task. It is implicitly carried with the task, and is accessible by any child tasks the task creates (such as TaskGroup or async let created tasks).
   */
  @TaskLocal static var supportsPartialDownloads = false
  
  /// Downloads a file and returns its content.
  func download(file: DownloadFile) async throws -> Data {
    guard let url = URL(string: "http://localhost:8080/files/download?\(file.name)") else {
      throw "Could not create the URL."
    }
    
    await addDownload(name: file.name)
    
    let (data, response) = try await
    URLSession.shared.data(from: url, delegate: nil)
    
    await updateDownload(name: file.name, progress: 1.0)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    return data
  }
  
  /// Downloads a file, returns its data, and updates the download progress in ``downloads``.
  func downloadWithProgress(file: DownloadFile) async throws -> Data {
    return try await downloadWithProgress(fileName: file.name,
                                          name: file.name,
                                          size: file.size)
  }
  
  /// Downloads a file, returns its data, and updates the download progress in ``downloads``.
  private func downloadWithProgress(fileName: String, name: String, size: Int, offset: Int? = nil) async throws -> Data {
    guard let url = URL(string: "http://localhost:8080/files/download?\(fileName)") else {
      throw "Could not create the URL."
    }
    await addDownload(name: name)
    
    let result: (downloadStream: URLSession.AsyncBytes, response: URLResponse)
    
    if let offset = offset {
      // 在这里, 进行了类似于断点续传的工作.
      let urlRequest = URLRequest(url: url, offset: offset, length: size)
      // 这里进行 Await, 是因为网络请求, Response 的到达, 其实也是一个异步的过程. 
      result = try await URLSession.shared.bytes(for: urlRequest, delegate: nil)
      
      guard (result.response as? HTTPURLResponse)?.statusCode == 206 else {
        throw "The server responded with an error."
      }
    } else {
      // 如果, 没有 offset 值, 就是重新进行下载的动作.
      result = try await URLSession.shared.bytes(from: url, delegate: nil)
      guard (result.response as? HTTPURLResponse)?.statusCode == 200 else {
        throw "The server responded with an error."
      }
    }
    
    var asyncDownloadIterator = result.downloadStream.makeAsyncIterator()
    
    let accumulator = ByteAccumulator(name: name, size: size)
    
    while !stopDownloads, !accumulator.checkCompleted() {
      while !accumulator.isBatchCompleted,
            let byte = try await asyncDownloadIterator.next() {
        accumulator.append(byte)
      }
      let progress = accumulator.progress
      // 在收集到相应的数据之后, 进行 UI 更新的工作.
      Task.detached(priority: .medium) {
        await self.updateDownload(name: name, progress: progress)
      }
      print(accumulator.description)
    }
    
    if stopDownloads, !Self.supportsPartialDownloads {
      throw CancellationError()
    }
    
    return accumulator.data
  }
  
  /// Downloads a file using multiple concurrent connections, returns the final content, and updates the download progress.
  func multiDownloadWithProgress(file: DownloadFile) async throws -> Data {
    func partInfo(index: Int, of count: Int) -> (offset: Int, size: Int, name: String) {
      let standardPartSize = Int((Double(file.size) / Double(count)).rounded(.up))
      let partOffset = index * standardPartSize
      let partSize = min(standardPartSize, file.size - partOffset)
      let partName = "\(file.name) (part \(index + 1))"
      return (offset: partOffset, size: partSize, name: partName)
    }
    let total = 4
    let parts = (0..<total).map { partInfo(index: $0, of: total) }
    // Add challenge code here.
    return Data()
  }
  
  /// Flag that stops ongoing downloads.
  var stopDownloads = false
  
  func reset() {
    stopDownloads = false
    downloads.removeAll()
  }
  
  func availableFiles() async throws -> [DownloadFile] {
    guard let url = URL(string: "http://localhost:8080/files/list") else {
      throw "Could not create the URL."
    }
    
    let (data, response) = try await
    URLSession.shared.data(from: url)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    guard let list = try? JSONDecoder()
      .decode([DownloadFile].self, from: data) else {
      throw "The server response was not recognized."
    }
    
    return list
  }
  
  func status() async throws -> String {
    guard let url = URL(string: "http://localhost:8080/files/status") else {
      throw "Could not create the URL."
    }
    
    let (data, response) = try await
    URLSession.shared.data(from: url, delegate: nil)
    
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw "The server responded with an error."
    }
    
    return String(decoding: data, as: UTF8.self)
  }
}

extension SuperStorageModel {
  /// Adds a new download.
  @MainActor func addDownload(name: String) {
    let downloadInfo = DownloadInfo(id: UUID(), name: name, progress: 0.0)
    downloads.append(downloadInfo)
  }
  
  /// Updates a the progress of a given download.
  @MainActor func updateDownload(name: String, progress: Double) {
    if let index = downloads.firstIndex(where: { $0.name == name }) {
      var info = downloads[index]
      info.progress = progress
      downloads[index] = info
    }
  }
}
