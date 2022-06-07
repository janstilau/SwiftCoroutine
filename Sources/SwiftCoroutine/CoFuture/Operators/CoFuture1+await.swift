//
//  CoFuture3+await.swift
//  SwiftCoroutine
//
//  Created by Alex Belozierov on 31.12.2019.
//  Copyright © 2019 Alex Belozierov. All rights reserved.
//

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
        /*
         addCallback 当做 asyncAction, 会在 wait 中触发. 将 await 中取值并且 resume 的过程, 存储到了 Future 的 Result 回调里面.
         在 Future 进行了赋值之后, 会进行逻辑的触发.
         
         而 Future Result 的值的赋值, 是 Future 返回之前, 就写好在异步回调里面的. 
         */
        // 对于 Result 来说, get 时如果是 failure 的状态, 会触发 throw 的逻辑 .
        // Result 一般用作是异步结果, 如果想要重新变为同步处理逻辑, get 是一个很好的选择. 
        try (result ?? Coroutine.current().await(addCallback)).get()
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
        let result: Result<Value, Error> = try Coroutine.current().await { callback in
            self.addCallback(callback)
            timer.setEventHandler { callback(.failure(CoFutureError.timeout)) }
            timer.start()
        }
        return try result.get()
    }
    
}
