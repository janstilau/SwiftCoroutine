import SwiftUI

struct LoginView: View {
  /*
   A property wrapper type that reflects a value from UserDefaults and invalidates a view on a change in value in that user default.
   */
  @AppStorage("username") var username = ""
  @State var isDisplayingChat = false
  @State var model = BlabberModel()
  
  var body: some View {
    VStack {
      Text("Blabber")
      // 这个特殊的字体, 看起来像是幼圆
        .font(.custom("Lemon", size: 48))
        .foregroundColor(Color.teal)
      
      HStack {
        // 使用 $@State 这种方式, 进行了数据的双向绑定. 
        TextField(text: $username, prompt: Text("Username")) { }
          .textFieldStyle(RoundedBorderTextFieldStyle())
        
        Button(action: {
          // ViewAction 中, 进行 ViewModel 的值修改.
          model.loginUser = username
          // 在 ViewAction 里面, 修改 isDisplayingChat @State 的值 .
          // 这个值的改变, 使得 ChatView 被弹出.
          self.isDisplayingChat = true
        }, label: {
          Image(systemName: "arrow.right.circle.fill")
            .font(.title)
            .foregroundColor(Color.teal)
        })
        .sheet(isPresented: $isDisplayingChat, onDismiss: {}, content: {
          ChatView(model: model)
        })
      }
      .padding(.horizontal)
    }
    .statusBar(hidden: true)
  }
}
