import SwiftUI
import UIKit

/// The file download view.
struct DownloadView: View {
  /// The selected file.
  let file: DownloadFile
  @EnvironmentObject var model: SuperStorageModel
  /// The downloaded data.
  @State var fileData: Data?
  
  /// Should display a download activity indicator.
  // 是否应该展示菊花状态, 这是一个 ViewState.
  // 不过, 这里没有修改这个状态的地方. 
  @State var isDownloadActive = false
  var body: some View {
    List {
      // Show the details of the selected file and download buttons.
      FileDetails(
        file: file,
        isDownloading: !model.downloads.isEmpty,
        isDownloadActive: $isDownloadActive,
        
        // 各种 ViewAction 的回调, 还是通过 Block 的方式, 进行了存储.
        // 在上一层进行初始化的时候,
        downloadSingleAction: {
          // Download a file in a single go.
          print("downloadSingleAction")
          // 当, 点击了按钮之后, 触发下载操作.
          // 当, 下载完成之后, 触发 Model 的改变, 然后触发 View 的改变.
          
          // 使用, Task, 将异步函数的执行环境创建出来.
          Task {
            fileData = try await model.download(file: file)
          }
        },
        downloadWithUpdatesAction: {
          // Download a file with UI progress updates.
          print("downloadWithUpdatesAction")
        },
        downloadMultipleAction: {
          // Download a file in multiple concurrent parts.
          print("downloadMultipleAction")
        }
      )
      .border(Color.red, width: 2)
      
      if !model.downloads.isEmpty {
        // Show progress for any ongoing downloads.
        DownloadsProgress(downloads: model.downloads).border(Color.green)
      }
      
      if let fileData = fileData {
        // Show a preview of the file if it's a valid image.
        FilePreview(fileData: fileData).border(Color.purple, width: 2)
      }
    }
    .animation(.easeOut(duration: 0.33), value: model.downloads)
    .listStyle(InsetGroupedListStyle())
    .toolbar(content: {
      Button(action: {
        // 这里, 按钮点击了之后, 其实是没有效果.
        // 使用, viewModel 的 Published 成员进行了绑定, 所以 View 可以自动的进行更新.
      }, label: { Text("Cancel All") })
      .disabled(model.downloads.isEmpty)
    })
    /*
     Summary
     Adds an action to perform when this view disappears.
     Declaration
     func onDisappear(perform action: (() -> Void)? = nil) -> some View
     Parameters
     action
     The action to perform. If action is nil, the call has no effect.
     Returns
     A view that triggers action when this view disappears.
     */
    .onDisappear {
      // 为什么, 各种 View 消失之后, 可以进行状态的重设, 就是因为在 onDisappear 里面, 可以绑定一个当对应的时机, 进行调用的 Block .
      fileData = nil
      model.reset()
    }
  }
}
