import SwiftUI

struct Downloads: View {
  let downloads: [DownloadInfo]
  var body: some View {
    ForEach(downloads) { download in
      VStack(alignment: .leading) {
        Text(download.name).font(.caption)
        ProgressView(value: download.progress)
      }
    }
  }
}
