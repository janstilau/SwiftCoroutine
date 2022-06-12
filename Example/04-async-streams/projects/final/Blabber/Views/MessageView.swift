import SwiftUI

/// A chat message view.
struct MessageView: View {
  @Binding var message: Message
  let myUser: String
  
  // 将, 如何显示的颜色信息, 抽取到这里来.
  // 发出和接收的分别, 就在这个函数里面.
  private func color(for username: String?, myUser: String) -> Color {
    guard let username = username else {
      return Color.clear
    }
    return username == myUser ? Color.teal : Color.orange
  }
  
  var body: some View {
    HStack {
      if myUser == message.user {
        Spacer()
      }
      
      VStack(alignment: myUser == message.user ? .trailing : .leading) {
        if let user = message.user {
          // 如果, 消息有人名, 那么首先把人名显示到屏幕上.
          HStack {
            if myUser != message.user {
              Text(user).font(.callout)
            }
          }
        }
        
        // 然后, 显示消息的内容.
        Text(message.message)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .overlay {
            RoundedRectangle(cornerRadius: 15)
              .strokeBorder(color(for: message.user, myUser: myUser), lineWidth: 1)
          }
      }
      
      if myUser != message.user && message.user != nil {
        Spacer()
      }
    }
    .padding(.vertical, 2)
    .frame(maxWidth: .infinity)
  }
}
