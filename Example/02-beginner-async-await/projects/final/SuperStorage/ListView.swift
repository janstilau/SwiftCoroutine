import SwiftUI

/// The main list of available for download files.
struct ListView: View {
  let model: SuperStorageModel
  // The file list.
  // 其实, 应该在 ViewModel 中存储这个值.
  // 现在这个值, 变为了只读属性了, 仅仅是为了进行展示的.
  // ViewModel 的数据, 没有和 View 进行绑定.
  @State var files: [DownloadFile] = []
  /// The server status message.
  // 用来存储, 网络请求的状态.
  @State var status = ""
  /// The file to present for download.
  // 存储当前被选中的 File Model.
  // isDisplayingDownload 和 selected 是两个含义, 所以应该使用两个变量进行记录.
  // 并且, isDisplayingDownload 还会和 Push 的生命周期绑定, 当 Pop 的时候, 会将这个值, 置为 False .
  @State var selected = DownloadFile.empty {
    didSet {
      isDisplayingDownload = true
    }
  }
  @State var isDisplayingDownload = false
  
  /// The latest error message.
  // 当, ViewModel 的网络请求错误的时候, 就会将这个值进行赋值.
  @State var lastErrorMessage = "None" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false
  
  var body: some View {
    NavigationView {
      VStack {
        
        /*
         hidden()
         
         Hides this view unconditionally.
         Declaration

         func hidden() -> some View
         Discussion

         Hidden views are invisible and can’t receive or respond to interactions. However, they do remain in the view hierarchy and affect layout. Use this modifier if you want to include a view for layout purposes, but don’t want it to display.
         使用 Hidden 进行 View 的隐藏, 但是不会影响到这个 View 的布局相关的影响.
         
         HStack {
             Image(systemName: "a.circle.fill")
             Image(systemName: "b.circle.fill")
             Image(systemName: "c.circle.fill")
                 .hidden()
             Image(systemName: "d.circle.fill")
         }
         The third circle takes up space, because it’s still present, but SwiftUI doesn’t draw it onscreen.
         If you want to conditionally include a view in the view hierarchy, use an if statement instead:
         VStack {
             HStack {
                 Image(systemName: "a.circle.fill")
                 Image(systemName: "b.circle.fill")
         // 使用这种方式, 可以影响到布局了.
                 if !isHidden {
                     Image(systemName: "c.circle.fill")
                 }
                 Image(systemName: "d.circle.fill")
             }
             Toggle("Hide", isOn: $isHidden)
         }
         Depending on the current value of the isHidden state variable in the example above, controlled by the Toggle instance, SwiftUI draws the circle or completely omits it from the layout.
         Returns

         A hidden view.
         */
        
        /*
         NavigationLink
         
         Summary

         A view that controls a navigation presentation.
         Declaration

         struct NavigationLink<Label, Destination> where Label : View, Destination : View
         Discussion

         Users click or tap a navigation link to present a view inside a NavigationView. You control the visual appearance of the link by providing view content in the link’s trailing closure. For example, you can use a Label to display a link:
         NavigationLink(destination: FolderList(id: workFolder.id)) {
             Label("Work Folder", systemImage: "folder")
         }
         For a link composed only of text, you can use one of the convenience initializers that takes a string and creates a Text view for you:
         NavigationLink("Work Folder", destination: FolderList(id: workFolder.id))
         Perform navigation by initializing a link with a destination view. For example, consider a ColorDetail view that displays a color sample:
         struct ColorDetail: View {
             var color: Color

             var body: some View {
                 color
                     .frame(width: 200, height: 200)
                     .navigationTitle(color.description.capitalized)
             }
         }
         The following NavigationView presents three links to color detail views:
         NavigationView {
             List {
                 NavigationLink("Purple", destination: ColorDetail(color: .purple))
                 NavigationLink("Pink", destination: ColorDetail(color: .pink))
                 NavigationLink("Orange", destination: ColorDetail(color: .orange))
             }
             .navigationTitle("Colors")

             Text("Select a Color") // A placeholder to show before selection.
         }
         
         // 从这我们看到, 使用这种方式进行程序化的跳转, 是官方推荐的做法.
         // 这种做法, 相当于是提前创建了 navigation 的逻辑, 然后使用 Bool 值进行触发.
         Optionally, you can use a navigation link to perform navigation programmatically. You do so in one of two ways:
         Bind the link’s isActive parameter to a Boolean value. Setting the value to true performs the navigation.
         Bind the link’s selection parameter to a value and provide a tag of the variable’s type. Setting the value of selection to tag performs the navigation.
         For example, you can create a State variable that indicates when the purple page in the previous example appears:
         @State private var shouldShowPurple = false
         Then you can modify the purple navigation link to bind to the state variable:
         NavigationLink(
             "Purple",
             destination: ColorDetail(color: .purple),
             isActive: $shouldShowPurple)
         If elsewhere in your code you set shouldShowPurple to true, the navigation link activates.
         */
        NavigationLink(destination: DownloadView(file: selected).environmentObject(model),
                       isActive: $isDisplayingDownload) {
          EmptyView()
        }.hidden()
        
        // The list of files avalable for download.
        List {
          /*
           A container view that you can use to add hierarchy to certain collection views.
           Declaration

           struct Section<Parent, Content, Footer>
           Discussion

           Use Section instances in views like List, Picker, and Form to organize content into separate sections.
           Each section has custom content that you provide on a per-instance basis. You can also provide headers and footers for each section.
           */
          Section(content: {
            // 如果, files 是空, 那么菊花 Loading 会显示在最顶部.
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
      // 当, 网络出错的时候, 会给 $isDisplayingError 进行赋值.
      // $isDisplayingError 的改变, 会引起 Alert 的改变.
      .alert("Error", isPresented: $isDisplayingError, actions: {
        Button("Close", role: .cancel) { }
      }, message: {
        Text(lastErrorMessage)
      })
      .task {
        guard files.isEmpty else { return }
        
        do {
          // 创建结构化的任务
          async let files = try model.availableFiles()
          async let status = try model.status()
          // 当, 结构化的任务完成之后, 才会继续下面的流程.
          let (filesResult, statusResult) = try await (files, status)
          
          // 异步结束之后, 进行 UI 的更新.
          // 在 availableFiles 中还是子线程的环境, 到这里, 就是主线程了.
          // SwiftUI 自动进行了切换????
          self.files = filesResult
          self.status = statusResult
        } catch {
          lastErrorMessage = error.localizedDescription
        }
      }
    }
  }
}
