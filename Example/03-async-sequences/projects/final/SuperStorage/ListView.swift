import SwiftUI

/// The main list of available for download files.
struct ListView: View {
  let model: SuperStorageModel
  /// The file list.
  @State var files: [DownloadFile] = []
  /// The server status message.
  @State var status = ""
  /// The file to present for download.
  @State var selected = DownloadFile.empty {
    didSet {
      isDisplayingDownload = true
    }
  }
  @State var isDisplayingDownload = false
  
  /// The latest error message.
  @State var lastErrorMessage = "None" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false
  
  var body: some View {
    NavigationView {
      VStack {
        // Programatically push the file download view.
        NavigationLink(destination: DownloadView(file: selected).environmentObject(model),
                       isActive: $isDisplayingDownload) {
          EmptyView()
        }.hidden()
        // The list of files avalable for download.
        List {
          Section(content: {
            if files.isEmpty {
              ProgressView().padding()
            }
            ForEach(files) { file in
              Button(action: {
                selected = file
              }, label: {
                FileListItem(file: file)
              })
            }
          }, header: {
            Label(" SuperStorage", systemImage: "externaldrive.badge.icloud")
              .font(.custom("SerreriaSobria", size: 27))
              .foregroundColor(Color.accentColor)
              .padding(.bottom, 20)
          }, footer: {
            Text(status)
          })
        }
        .listStyle(InsetGroupedListStyle())
        .animation(.easeOut(duration: 0.33), value: files)
      }
      .alert("Error", isPresented: $isDisplayingError, actions: {
        Button("Close", role: .cancel) { }
      }, message: {
        Text(lastErrorMessage)
      })
      .task {
        guard files.isEmpty else { return }
        
        do {
          async let files = try model.availableFiles()
          async let status = try model.status()
          
          let (filesResult, statusResult) = try await (files, status)
          
          self.files = filesResult
          self.status = statusResult
        } catch {
          lastErrorMessage = error.localizedDescription
        }
      }
    }
  }
}
