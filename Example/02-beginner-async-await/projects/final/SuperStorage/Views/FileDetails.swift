import SwiftUI

struct FileDetails: View {
  // 上级传递过来的, Model 数据
  // 可以看到, 当一个 View 仅仅是只有展示的功能的时候, 只需要 Model, 不需要 ViewModel/
  // ViewModel 是控制层层面的东西, 而这个 View 的交互, 是交给了 Block 进行配置.
  // 配置的工作在上级, 所以是上级的 ViewModel 掌控了这里 View 的交互.
  let file: DownloadFile
  let isDownloading: Bool
  
  // 上级页面传过来的, 是否进行 Loading 展示的 Bool 值.
  @Binding var isDownloadActive: Bool
  
  // 各种, 回调还是用 Block 的方式进行了传输了
  // 实际上, 使用 SwiftUI. 回调的传递, 也就是只能使用回调这种方式了.
  let downloadSingleAction: () -> Void
  let downloadWithUpdatesAction: () -> Void
  let downloadMultipleAction: () -> Void
  
  var body: some View {
    Section(content: {
      VStack(alignment: .leading) {
        // 文件 Title Label
        HStack(spacing: 8) {
          if isDownloadActive {
            ProgressView()
          }
          Text(file.name)
            .font(.title3)
        }
        .padding(.leading, 8)
        
        // 文件的 Size Label
        Text(sizeFormatter.string(fromByteCount: Int64(file.size)))
          .font(.body)
          .foregroundColor(Color.indigo)
          .padding(.leading, 8)
        
        // 文件的 Action 排列.
        if !isDownloading {
          HStack {
            Button(action: downloadSingleAction) {
              Image(systemName: "arrow.down.app")
              Text("Silver")
            }
            .tint(Color.teal)
            Button(action: downloadWithUpdatesAction) {
              Image(systemName: "arrow.down.app.fill")
              Text("Gold")
            }
            .tint(Color.pink)
            Button(action: downloadMultipleAction) {
              Image(systemName: "dial.max.fill")
              Text("Cloud 9")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.purple)
          }
          .buttonStyle(.bordered)
          .font(.subheadline)
        }
      }
    }, header: {
      // 每一个 Section, 都有一个 Header 可以进行配置.
      // 这里 Body 是利用了 Section 这种 Container 的结构, 来做 FileDetail View 的构建.
      Label(" Download", systemImage: "arrow.down.app")
        .font(.custom("SerreriaSobria", size: 27))
        .foregroundColor(Color.accentColor)
        .padding(.bottom, 20)
    })
  }
}
