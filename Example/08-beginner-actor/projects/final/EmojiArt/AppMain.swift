import SwiftUI

@main
struct AppMain: App {
  private var model = EmojiArtModel()
  
  @State private var isVerified = false
  
  var body: some Scene {
    WindowGroup {
      VStack {
        if isVerified {
          ListView()
            .environmentObject(ImageLoader())
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
