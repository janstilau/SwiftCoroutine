import Foundation

class ScanModel: ObservableObject {
  // MARK: - Private state
  private var counted = 0
  private var started = Date()
  
  // MARK: - Public, bindable state
  
  /// Currently scheduled for execution tasks.
  @MainActor @Published var scheduled = 0
  
  /// Completed scan tasks per second.
  @MainActor @Published var countPerSecond: Double = 0
  
  /// Completed scan tasks.
  @MainActor @Published var completed = 0
  
  @Published var total: Int
  
  @MainActor @Published var isCollaborating = false
  
  // MARK: - Methods
  
  init(total: Int, localName: String) {
    self.total = total
  }
  
  func runAllTasks() async throws {
    started = Date()
    try await withThrowingTaskGroup(of: Result<String, Error>.self) { [unowned self] group in
      let batchSize = 4
      
      for index in 0..<batchSize {
        group.addTask {
          await self.worker(number: index)
        }
      }
      
      // 先同时开启四个, 然后没完成一个, 新加入一个.
      var index = batchSize
      
      for try await result in group {
        switch result {
        case .success(let result):
          print("Completed: \(result)")
        case .failure(let error):
          print("Failed: \(error.localizedDescription)")
        }
        
        if index < total {
          group.addTask { [index] in
            await self.worker(number: index)
          }
          index += 1
        }
      }
      
      // 最后, 在主线程进行数据的归零操作.
      await MainActor.run {
        completed = 0
        countPerSecond = 0
        scheduled = 0
      }
      
      print("Done.")
    }
  }
  
  func worker(number: Int) async -> Result<String, Error> {
    // 在主线程, 进行数据的操作.
    await onScheduled()
    
    let task = ScanTask(input: number)
    
    let result: String
    do {
      result = try await task.run()
    } catch {
      return .failure(error)
    }
    
    // 在主线程, 进行数据的操作. 
    await onTaskCompleted()
    return .success(result)
  }
}

// MARK: - Tracking task progress.
extension ScanModel {
  @MainActor
  private func onTaskCompleted() {
    completed += 1
    counted += 1
    scheduled -= 1
    
    countPerSecond = Double(counted) / Date().timeIntervalSince(started)
  }
  
  @MainActor
  private func onScheduled() {
    scheduled += 1
  }
}
