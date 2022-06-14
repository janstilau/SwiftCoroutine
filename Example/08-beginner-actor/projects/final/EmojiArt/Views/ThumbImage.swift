import SwiftUI

struct ThumbImage: View {
  
  let file: ImageFile
  @State var image = UIImage()
  @State var overlay = ""
  @EnvironmentObject var imageLoader: ImageLoader
  
  // 在主线程, 进行 UI 的更新. 
  @MainActor func updateImage(_ image: UIImage) {
    self.image = image
  }
  
  var body: some View {
    Image(uiImage: image)
      .resizable()
      .aspectRatio(contentMode: .fill)
      .foregroundColor(.gray)
      .overlay {
        if !overlay.isEmpty {
          Image(systemName: overlay)
        }
      }
      .task {
        guard let image = try? await imageLoader.image(file.url) else {
          overlay = "camera.metering.unknown"
          return
        }
        updateImage(image)
      }
  }
}
