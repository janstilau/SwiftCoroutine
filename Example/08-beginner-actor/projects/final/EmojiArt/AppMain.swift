import SwiftUI

@main
struct AppMain: App {
  private var model = EmojiArtModel()
  
  @State private var isVerified = false
  
  var body: some Scene {
    WindowGroup {
      VStack {
        // 根据, isVerified 的值的不同, 显示不同的 View
        if isVerified {
          ListView().environmentObject(ImageLoader())
        } else {
          LoadingView(isVerified: $isVerified)
        }
      }
      .transition(.opacity)
      .animation(.linear, value: isVerified)
      // 进行了环境变量的注册.
      .environmentObject(model)
    }
  }
}
