import SwiftUI

struct BottomToolbar: View {
  @EnvironmentObject var model: EmojiArtModel
  
  @State var onDiskAccessCount = 0
  @State var inMemoryAccessCount = 0
  
  var body: some View {
    HStack {
      Button(action: {
        // Clear on-disk cache
      }, label: {
        Image(systemName: "folder.badge.minus")
      })
      
      Button(action: {
        // Clear in-memory cache
      }, label: {
        Image(systemName: "square.stack.3d.up.slash")
      })
      
      Spacer()
      Text("Access: \(onDiskAccessCount) from disk, \(inMemoryAccessCount) in memory")
        .font(.monospaced(.caption)())
    }
    .padding(.vertical, 2)
    .padding(.horizontal, 5)
  }
}
