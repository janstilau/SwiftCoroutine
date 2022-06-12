import SwiftUI

@main
struct SuperStorageApp: App {
  var body: some Scene {
    WindowGroup {
      ListView(model: SuperStorageModel())
    }
  }
}
