
// 提供, 特定条件的回调.
// 最终, 还是使用了 addCallback. 只不过是带有条件判断了. 
extension CoFuture {
    
    // MARK: - whenComplete
    
    /// Adds an observer callback that is called when the `CoFuture` has any result.
    /// - Parameter callback: The callback that is called when the `CoFuture` is fulfilled.
    @inlinable public func whenComplete(_ callback: @escaping (Result<Value, Error>) -> Void) {
        addCallback(callback)
    }
    
    /// Adds an observer callback that is called when the `CoFuture` has a success result.
    /// - Parameter callback: The callback that is called with the successful result of the `CoFuture`.
    // 其实, 就是 addCallback, 只不过是限定了只能是 result 是 success 的时候, 才能够调用.
    @inlinable public func whenSuccess(_ callback: @escaping (Value) -> Void) {
        addCallback { result in
            if case .success(let value) = result {
                callback(value)
            }
        }
    }
    
    /// Adds an observer callback that is called when the `CoFuture` has a failure result.
    /// - Parameter callback: The callback that is called with the failed result of the `CoFuture`.
    // 其实, 就是 addCallback, 只不过是限定了只能是 result 是 failure 的时候, 才能够调用.
    @inlinable public func whenFailure(_ callback: @escaping (Error) -> Void) {
        addCallback { result in
            if case .failure(let error) = result {
                callback(error)
            }
        }
    }
    
    /// Adds an observer callback that is called when the `CoFuture` is canceled.
    /// - Parameter callback: The callback that is called when the `CoFuture` is canceled.
    // 其实, 就是 addCallback, 只不过是限定了只能是 result 是 failure 的时候, 并且是 canceled 的时候, 才能够调用.
    @inlinable public func whenCanceled(_ callback: @escaping () -> Void) {
        addCallback { result in
            // 首先, 必须是失败了, 然后失败的类型, 必须是 cancel.
            // 这是一个非常通用的设计, 一个专门的 Error 类型, 来代表失败.
            if case .failure(let error as CoFutureError) = result,
               error == .canceled {
                callback()
            }
        }
    }
    
    /// Adds an observer callback that is called when the `CoFuture` has any result.
    /// - Parameter callback: The callback that is called when the `CoFuture` is fulfilled.
    // 包装了一层, 不需要进行 result 参数的处理了. 
    @inlinable public func whenComplete(_ callback: @escaping () -> Void) {
        whenComplete { _ in callback() }
    }
    
}
