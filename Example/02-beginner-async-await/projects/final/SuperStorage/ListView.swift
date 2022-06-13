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
         func hidden() -> some View

         Hidden views are invisible and can’t receive or respond to interactions. However, they do remain in the view hierarchy and affect layout.
         Use this modifier if you want to include a view for layout purposes, but don’t want it to display.
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
         // 使用这种方式, 可以影响到布局了. 每次当 isHidden 为 True 的时候, 第三个 Image 其实也就不显示了.
         // 每次, Body 都是全量获取数据, 所以布局相关也是重新计算的.
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

         Users click or tap a navigation link to present a view inside a NavigationView. You control the visual appearance of the link by providing view content in the link’s trailing closure.
         
         For example, you can use a Label to display a link:
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
        // 这里 link, 是 Hidden 的, 但是还是会占据空间的.
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
            // 将 View 的展示, 和 ViewState 进行了绑定.
            // 当 status 改变的时候, 也就是 View 改变的时候. 
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
      
      /*
       Adds an asynchronous task to perform when this view appears.
       func task(priority: TaskPriority = .userInitiated,
                _ action: @escaping () async -> Void)
       -> some View

       // 这样创建的任务, 是会和 View 的生命周期绑定在一起的.
       Use this modifier to perform an asynchronous task with a lifetime that matches that of the modified view. If the task doesn’t finish before SwiftUI removes the view or the view changes identity, SwiftUI cancels the task.
       Use the await keyword inside the task to wait for an asynchronous call to complete, or to wait on the values of an AsyncSequence instance. For example, you can modify a Text view to start a task that loads content from a remote resource:
       
       let url = URL(string: "https://example.com")!
       @State private var message = "Loading..."

       var body: some View {
           Text(message)
               .task {
                   do {
                       var receivedLines = [String]()
                       for try await line in url.lines {
                           receivedLines.append(line)
                           message = "Received \(receivedLines.count) lines"
                       }
                   } catch {
                       message = "Failed to load"
                   }
               }
       }
       
       This example uses the lines method to get the content stored at the specified URL as an asynchronous sequence of strings.
       When each new line arrives, the body of the for-await-in loop stores the line in an array of strings and updates the content of the text view to report the latest line count.

       priority
       The task priority to use when creating the asynchronous task. The default priority is userInitiated.
       
       action
       A closure that SwiftUI calls as an asynchronous task when the view appears. SwiftUI automatically cancels the task if the view disappears before the action completes.
       Returns

       A view that runs the specified action asynchronously when the view appears.
       */
      .task {
        guard files.isEmpty else { return }
        
        do {
          // 创建结构化的任务
          async let files = try model.availableFiles()
          async let status = try model.status()
          // 当, 结构化的任务完成之后, 才会继续下面的流程.
          
          Thread.dump("ListView Appeared")
          // 这里显示, 是主线程环境.
          let (filesResult, statusResult) = try await (files, status)
          
          Thread.dump("ListView Get Results")
          // 这里显示, 已经是主线程环境了.
          // 异步结束之后, 进行 UI 的更新. 为什么自动切换到了主线程.
          self.files = filesResult
          self.status = statusResult
        } catch {
          lastErrorMessage = error.localizedDescription
        }
      }
    }
  }
}
