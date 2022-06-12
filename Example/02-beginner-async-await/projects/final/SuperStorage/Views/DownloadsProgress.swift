import SwiftUI

struct DownloadsProgress: View {
  let downloads: [DownloadInfo]
  var body: some View {
    ForEach(downloads) { download in
      VStack(alignment: .leading) {
        // 下载的文件名.
        Text(download.name).font(.caption)
        // 下载的进度.
        // 所有的一些, 都是在 DownloadInfo 数据里面.
        ProgressView(value: download.progress)
      }
    }
  }
}
