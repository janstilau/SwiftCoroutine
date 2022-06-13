import SwiftUI

/// A view that displays a preset text animation.
struct TitleView: View {
  /// The title animates when this property is `true`.
  @Binding var isAnimating: Bool
  
  @State private var title = "s|2 |2k|0 |1y|3"
  @State private var titleIndex = 0
  
  @State private var timer = Timer.publish(every: 0.33, tolerance: 1, on: .main, in: .common)
    .autoconnect()
  
  static private let titleAnimation = [
    "s|2 |2k|0 |1y|3 |2n|1 |0e|1 |1t|2",
    "s|2 |2k|2 |0y|1 |3n|2 |1e|0 |1t|1",
    "s|1 |2k|2 |2y|0 |1n|3 |2e|1 |0t|1",
    "s|1 |1k|2 |2y|2 |0n|1 |3e|2 |1t|0",
    "s|0 |1k|1 |2y|2 |2n|0 |1e|3 |2t|1"
  ]
  
  // 没太理这个类, 和主逻辑, 没有太大的关系. 
  private func updateTitle() {
    titleIndex += 1
    if titleIndex >= Self.titleAnimation.count {
      titleIndex = 0
    }
    title = Self.titleAnimation[titleIndex]
  }
  
  var body: some View {
    Text(title)
      .font(.custom("Datalegreya-Gradient", size: 36, relativeTo: .largeTitle))
      .onReceive(timer) { _ in
        if isAnimating {
          self.updateTitle()
        }
      }
  }
}
