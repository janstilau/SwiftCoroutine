
import Dispatch

extension CoFuture {
    
    // MARK: - await
    
    /// Await for the result of this `CoFuture` without blocking the current thread. Must be called inside a coroutine.
    /// ```
    /// //execute someSyncFunc() on global queue and return its future result
    /// let future = DispatchQueue.global().coroutineFuture { someSyncFunc() }
    /// //start coroutine on main thread
    /// DispatchQueue.main.startCoroutine {
    ///     //await result of future
    ///     let result = try future.await()
    /// }
    /// ```
    /// - Throws: The failed result of the `CoFuture`.
    /// - Returns: The value of the `CoFuture` when it is completed.
    @inlinable public func await() throws -> Value {
        // result 里面可能是 error 信息, 所以 get 可能会 throws .
        try (result ?? CoroutineStruct.current().await(addCallback)).get()
    }
    
    /// Await for the result of this `CoFuture` without blocking the current thread. Must be called inside a coroutine.
    /// - Parameter timeout: The time interval to await for a result.
    /// - Throws: The failed result of the `CoFuture`.
    /// - Returns: The value of the `CoFuture` when it is completed.
    public func await(timeout: DispatchTimeInterval) throws -> Value {
        if let result = result { return try result.get() }
        
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + timeout)
        defer { timer.cancel() }
        let result: Result<Value, Error> = try CoroutineStruct.current().await { ResumeCallback in
            /*
             guard self.completionInvokeOnlyOnceTag == tag else { return }
             之前在 ShareRoutine 里面, 还对于上面的逻辑感到奇怪.
             下面两句话, 其实都会引起协程的唤醒操作. 这是正常的业务逻辑, 所以在 ShareRoutine 里面, 其实是有着只调用一次的判断的
             */
            self.addCallback(ResumeCallback)
            timer.setEventHandler { ResumeCallback(.failure(CoFutureError.timeout)) }
            timer.start()
        }
        return try result.get()
    }
    
}
