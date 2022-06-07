
extension CoFuture {
    
    // MARK: - map
    
    /// When future is fulfilled, run the provided callback, which performs a synchronous computation and return transformed value.
    /// - Parameter transform: Function that will receive the value and return a new transformed value or throw an error.
    /// - returns: A future that will receive the eventual value.
    @inlinable public func map<NewValue>(_ transform: @escaping (Value) throws -> NewValue) -> CoFuture<NewValue> {
        mapResult { result in
            Result { try transform(result.get()) }
        }
    }
    
    /// When future is in an error state, run the provided callback, which can recover from the error and return a new value.
    /// - Parameter transform: Function that will receive the error and return a new value or throw an error.
    /// - returns: A future that will receive the recovered value.
    @inlinable public func recover(_ transform: @escaping (Error) throws -> Value) -> CoFuture {
        mapResult { result in
            result.flatMapError { error in
                Result { try transform(error) }
            }
        }
    }
    
    // 实际上, 这里是一个类似于 Promise 的链路搭建的结果. 
    /// When future is fulfilled, run the provided callback, which performs a synchronous computation and return transformed result.
    /// - Parameter transform: Function that will receive the result and return a new transformed result.
    /// - returns: A future that will receive the eventual result.
    public func mapResult<NewValue>(_ transform: @escaping (Result<Value, Error>) -> Result<NewValue, Error>) -> CoFuture<NewValue> {
        if let result = result {
            return CoFuture<NewValue>(result: transform(result))
        }
        
        // 新建一个对象, 在这个对象里面, 进行回调的挂钩.
        let promise = CoPromise<NewValue>(parent: self)
        addCallback { promise.setResult(transform($0)) }
        return promise
    }
    
}
