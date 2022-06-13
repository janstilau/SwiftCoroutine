import SwiftUI
import Combine

@main
struct SkyApp: App {
  
  @ObservedObject
  var scanModel = ScanModel(total: 30, localName: UIDevice.current.name)
  
  @State var isScanning = false
  
  // 当, lastMessage 被赋值的时候, 进行弹出变量的赋值.
  // 这样, 就能控制弹出效果了.
  @State var lastMessage = "" {
    didSet {
      isDisplayingMessage = true
    }
  }
  @State var isDisplayingMessage = false
  
  var body: some Scene {
    WindowGroup {
      NavigationView {
        VStack {
          TitleView(isAnimating: $scanModel.isCollaborating)
          
          Text("Scanning deep space")
            .font(.subheadline)
          
          ScanningView(
            total: $scanModel.total,
            completed: $scanModel.completed,
            perSecond: $scanModel.countPerSecond,
            scheduled: $scanModel.scheduled
          )
          
          Button(action: {
            // Button 的点击之后, 是启动了一个异步任务. 在这个异步任务里面, 完成主逻辑.
            Task {
              isScanning = true
              do {
                let start = Date().timeIntervalSinceReferenceDate
                try await scanModel.runAllTasks()
                // 等待上面的异步操作结束, 然后进行 lastMessage 的赋值.
                let end = Date().timeIntervalSinceReferenceDate
                lastMessage = String(
                  format: "Finished %d scans in %.2f seconds.",
                  scanModel.total,
                  end - start
                )
              } catch {
                lastMessage = error.localizedDescription
              }
              isScanning = false
            }
          }, label: {
            HStack(spacing: 6) {
              if isScanning { ProgressView() }
              Text("Engage systems")
            }
          })
          .buttonStyle(.bordered)
          .disabled(isScanning)
        }
        
        .alert("Message", isPresented: $isDisplayingMessage, actions: {
          Button("Close", role: .cancel) { }
        }, message: {
          Text(lastMessage)
        })
        .padding()
        .statusBar(hidden: true)
      }
    }
  }
}
