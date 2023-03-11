
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
    
    /// When future is fulfilled, run the provided callback, which performs a synchronous computation and return transformed result.
    /// - Parameter transform: Function that will receive the result and return a new transformed result.
    /// - returns: A future that will receive the eventual result.
    public func mapResult<NewValue>(_ transform: @escaping (Result<Value, Error>) -> Result<NewValue, Error>) -> CoFuture<NewValue> {
        if let result = result {
            return CoFuture<NewValue>(result: transform(result))
        }
        // Promise 带有 Parent 信息, 主要是因为发生了变形
        // 返回了一个新的 Promise, 新的 Promise 的结果, 会在自己 Result 确定之后, transfrom , 然后进行 set.
        let promise = CoPromise<NewValue>(parent: self)
        addCallback { promise.setResult(transform($0)) }
        return promise
    }
    
}
