import SwiftUI

@main
struct LittleJohnApp: App {
  var body: some Scene {
    WindowGroup {
      SymbolListView(model: LittleJohnModel())
    }
  }
}
