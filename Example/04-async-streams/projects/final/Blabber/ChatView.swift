import SwiftUI

struct ChatView: View {
  @ObservedObject var model: BlabberModel
  
  @FocusState var focused: Bool
  
  /// The message that the user has typed.
  @State var message = ""
  
  /// The last error message that happened.
  @State var lastErrorMessage = "" {
    didSet {
      isDisplayingError = true
    }
  }
  @State var isDisplayingError = false
  
  @Environment(\.presentationMode) var presentationMode
  
  var body: some View {
    VStack {
      ScrollView(.vertical) {
        ScrollViewReader { reader in
          ForEach($model.messages) { message in
            MessageView(message: message, myUser: model.loginUser)
          }
          .onChange(of: model.messages.count) { _ in
            guard let last = model.messages.last else { return }
            withAnimation(.easeOut) {
              reader.scrollTo(last.id, anchor: .bottomTrailing)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      
      HStack {
        // 位置按钮点击的回调, 里面其实啥都没干. 
        Button(action: {
          Task {
            do {
              try await model.shareLocation()
            } catch {
              lastErrorMessage = error.localizedDescription
            }
          }
        }, label: {
          Image(systemName: "location.circle.fill")
            .font(.title)
            .foregroundColor(Color.gray)
        })
        
        // 历史按钮点击的回调.
        Button(action: {
          Task {
            do {
              let countdownMessage = message
              message = ""
              try await model.countdown(to: countdownMessage)
            } catch {
              lastErrorMessage = error.localizedDescription
            }
          }
        }, label: {
          Image(systemName: "timer")
            .font(.title)
            .foregroundColor(Color.gray)
        })
        
        // 输入框,
        // 和 message 进行双向绑定.
        TextField(text: $message, prompt: Text("Message")) {
          Text("Enter message")
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .focused($focused)
        .onSubmit {
          Task {
            try await model.say(message)
            message = ""
          }
          focused = true
        }
        
        Button(action: {
          Task {
            try await model.say(message)
            message = ""
          }
        }, label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title)
        })
      }
    }
    .padding()
    .onAppear {
      focused = true
    }
    // 这种, 专门的使用一个 Bool 值来进行 Alert 弹出的操作, 在 Swift UI 里面非常常见.
    // 因为 Swfit UI 其实要把所有的 View 都写到文件里面, 所以, 要使用 ViewState 来控制特定的 View 的展示.
    // 这是一种惯例的实现方式.
    .alert("Error", isPresented: $isDisplayingError, actions: {
      Button("Close", role: .cancel) {
        self.presentationMode.wrappedValue.dismiss()
      }
    }, message: {
      Text(lastErrorMessage)
    })
    .task {
      do {
        try await model.startChat()
      } catch {
        lastErrorMessage = error.localizedDescription
      }
    }
  }
}
