import SwiftUI
import Combine
import UIKit

/// The file download view.
struct DownloadView: View {
  /// The selected file.
  let file: DownloadFile
  @EnvironmentObject var model: SuperStorageModel
  /// The downloaded data.
  @State var fileData: Data?
  /// Should display a download activity indicator.
  // 在下载任务开启结束的时候, 会修改这个值.
  @State var isDownloadActive = false
  @State var duration = ""
  
  // 当, downloadTask 被赋值之后, 也就是新的下载任务开启的时候.
  // 这是时候, 开启一个新的定时器任务, 来进行 UI 的更新.
  @State var downloadTask: Task<Void, Error>? {
    didSet {
      timerTask?.cancel()
      
      guard isDownloadActive else { return }
      
      let startTime = Date().timeIntervalSince1970
      let timerSequence = Timer
        .publish(every: 1, tolerance: 1, on: .main, in: .common)
        .autoconnect()
        .map { date -> String in
          // 将当前的时间, 和 startTime 进行比较.
          let duration = Int(date.timeIntervalSince1970 - startTime)
          return "\(duration)s"
        }
      /*
       extension Publisher where Self.Failure == Never {
       /// The elements produced by the publisher, as an asynchronous sequence.
       /// This property provides an ``AsyncPublisher``, which allows you to use the Swift `async`-`await` syntax to receive the publisher's elements. Because ``AsyncPublisher`` conforms to <doc://com.apple.documentation/documentation/Swift/AsyncSequence>, you iterate over its elements with a `for`-`await`-`in` loop, rather than attaching a subscriber.
       
       /// The following example shows how to use the `values` property to receive elements asynchronously. The example adapts a code snippet from the ``Publisher/filter(_:)`` operator's documentation, which filters a sequence to only emit even integers.
       /// This example replaces the ``Subscribers/Sink`` subscriber with a `for`-`await`-`in` loop that iterates over the ``AsyncPublisher`` provided by the `values` property.
       ///
       ///     let numbers: [Int] = [1, 2, 3, 4, 5]
       ///     let filtered = numbers.publisher
       ///         .filter { $0 % 2 == 0 }
       ///
       ///     for await number in filtered.values
       ///     {
       ///         print("\(number)", terminator: " ")
       ///     }
       ///
       public var values: AsyncPublisher<Self> { get }
       }
       */
        .values
      
      timerTask = Task {
        // 将 Combine 中的技术, 应用到了 async 的场景里面.
        for await duration in timerSequence {
          print("Thread: \(Thread.current)")
          // 这里打印的都是主线程.
          self.duration = duration
        }
      }
    }
  }
  @State var timerTask: Task<Void, Error>?
  
  var body: some View {
    List {
      // Show the details of the selected file and download buttons.
      FileDetails(
        file: file,
        isDownloading: !model.downloads.isEmpty,
        // 使用 Binding 的方式, 当当前 ViewState 的 $isDownloadActive 改变的时候.
        // 子 View 的 isDownloadActive 也会同时发生改变, 然后触发子 View 的刷新.
        isDownloadActive: $isDownloadActive,
        downloadSingleAction: {
          // Download a file in a single go.
          isDownloadActive = true
          Task {
            do {
              fileData = try await model.download(file: file)
            } catch { }
            isDownloadActive = false
          }
        },
        
        downloadWithUpdatesAction: {
          isDownloadActive = true
          downloadTask = Task {
            do {
              /*
               Binds the task-local to the specific value for the duration of the asynchronous operation.
               final func withValue<R>(_ valueDuringOperation: Bool, operation: () async throws -> R, file: String = #file, line: UInt = #line) async rethrows -> R
               The value is available throughout the execution of the operation closure, including any get operations performed by child-tasks created during the execution of the operation closure.
               If the same task-local is bound multiple times, be it in the same task, or in specific child tasks, the more specific (i.e. “deeper”) binding is returned when the value is read.
               If the value is a reference type, it will be retained for the duration of the operation closure.
               */
              try await SuperStorageModel
                .$supportsPartialDownloads
                .withValue(file.name.hasSuffix(".jpeg")) {
                  fileData = try await model.downloadWithProgress(file: file)
                }
            } catch { }
            // 因为上面是 await 的调用, 所以能够到达这里, 就是上面的异步任务, 已经完成了.
            isDownloadActive = false
          }
        },
        
        downloadMultipleAction: {
          // Download a file in multiple concurrent parts.
        }
      )
      
      if !model.downloads.isEmpty {
        // Show progress for any ongoing downloads.
        Downloads(downloads: model.downloads)
      }
      
      if !duration.isEmpty {
        Text("Duration: \(duration)")
          .font(.caption)
      }
      
      /*
       fileData 会在按钮点击的回调里面, 调用异步函数进行赋值的动作.
       因为这是一个 @state 的变量, 所以他的修改, 其实会导致 View 的改变.
       */
      if let fileData = fileData {
        // Show a preview of the file if it's a valid image.
        FilePreview(fileData: fileData)
      }
    }
    .animation(.easeOut(duration: 0.33), value: model.downloads)
    .listStyle(InsetGroupedListStyle())
    .toolbar(content: {
      Button(action: {
        model.stopDownloads = true
        timerTask?.cancel()
      }, label: { Text("Cancel All") })
      .disabled(model.downloads.isEmpty)
    })
    .onDisappear {
      fileData = nil
      model.reset()
      // 当界面消失之后, 主动的进行 Task 的取消动作
      downloadTask?.cancel()
    }
  }
}
