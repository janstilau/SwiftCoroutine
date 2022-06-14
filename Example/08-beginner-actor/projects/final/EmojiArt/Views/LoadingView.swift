import SwiftUI
import Combine

struct LoadingView: View {
  @EnvironmentObject var model: EmojiArtModel
  
  /// The latest error message.
  @State var lastErrorMessage = "None" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false
  @State var progress = 0.0
  
  @Binding var isVerified: Bool
  
  let timer = Timer.publish(every: 0.2,
                            on: .main,
                            in: .common).autoconnect()
  
  var body: some View {
    VStack(spacing: 4) {
      
      ProgressView("Verifying feed", value: progress)
        .tint(.gray)
        .font(.subheadline)
      
      if !model.imageFeed.isEmpty {
        Text("\(Int(progress * 100))%")
          .fontWeight(.bold)
          .font(.caption)
          .foregroundColor(.gray)
      }
    }
    .padding(.horizontal, 20)
    .task {
      guard model.imageFeed.isEmpty else { return }
      Task {
        do {
          // 先获取图片列表.
          try await model.loadImages()
          // 然后并发.进行图片的检测
          try await model.verifyImages()
          withAnimation {
            isVerified = true
          }
        } catch {
          lastErrorMessage = error.localizedDescription
        }
      }
    }
    
    // 惯例的实现, 一个 Bool 值来控制 Alert 相关的操作.
    .alert("Error", isPresented: $isDisplayingError, actions: {
      Button("Close", role: .cancel) { }
    }, message: {
      Text(lastErrorMessage)
    })
    // Adds an action to perform when this view detects data emitted by the given publisher.
    // 这, 应该是会有 sink 的操作.
    .onReceive(timer) { _ in
      guard !model.imageFeed.isEmpty else { return }
      Task {
        
        progress = await Double(model.verifiedCount) / Double(model.imageFeed.count)
      }
    }
  }
}
