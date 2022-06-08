
// 就和 Publisher 的 Operator 一样, 是创建一个新的对象, 进行原有对象 Result 的串联.
extension CoFuture {
    
    // MARK: - flatMap
    // FlatMap 的使用方式, 和 Combine 中的 FlatMap 是一模一样的.
    
    /// When the current `CoFuture` is fulfilled, run the provided callback, which will provide a new `CoFuture`.
    /// This allows you to dynamically dispatch new asynchronous tasks as phases in a
    /// longer series of processing steps. Note that you can use the results of the
    /// current `CoFuture` when determining how to dispatch the next operation.
    /// - Parameter callback: Function that will receive the value and return a new `CoFuture`.
    /// - returns: A future that will receive the eventual value.
    @inlinable public func flatMap<NewValue>(_ callback: @escaping (Value) -> CoFuture<NewValue>) -> CoFuture<NewValue> {
        flatMapResult { result in
            switch result {
            case .success(let value):
                // 如果成功了, 使用 callback 来生成一个新的 Future 对象. 一般来说, 这里面应该带有异步操作才对. 
                return callback(value)
            case .failure(let error):
                // 如果是失败了, 直接就是错误的透传处理.
                return CoFuture<NewValue>(result: .failure(error))
            }
        }
    }
    
    /// When the current `CoFuture` is in an error state, run the provided callback, which
    /// may recover from the error by returning a `CoFuture`.
    /// - Parameter callback: Function that will receive the error value and return a new value lifted into a new `CoFuture`.
    /// - returns: A future that will receive the recovered value.
    @inlinable public func flatMapError(_ callback: @escaping (Error) -> CoFuture) -> CoFuture {
        flatMapResult { result in
            switch result {
            case .success:
                return CoFuture(result: result)
            case .failure(let error):
                return callback(error)
            }
        }
    }
    
    /// When the current `CoFuture` is fulfilled, run the provided callback, which will provide a new `CoFuture`.
    /// - Parameter callback: Function that will receive the result and return a new `CoFuture`.
    /// - returns: A future that will receive the eventual value.
    public func flatMapResult<NewValue>(_ callback: @escaping (Result<Value, Error>) -> CoFuture<NewValue>) -> CoFuture<NewValue> {
        if let result = result {
            return callback(result)
        }
        let promise = CoPromise<NewValue>(parent: self)
        // 这里类似于 Promise 的联动. 
        addCallback { callback($0).addCallback(promise.setResult) }
        return promise
    }
    
}
