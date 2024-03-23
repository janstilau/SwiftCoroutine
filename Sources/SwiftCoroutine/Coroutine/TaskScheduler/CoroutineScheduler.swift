/// A protocol that defines how to execute a task.
///
/// This protocol has extension methods that allow to launch coroutines on a current scheduler.
/// Inside the coroutine you can use such methods as `Coroutine.await(_:)`, `CoFuture.await()`,
/// and `CoroutineScheduler.await(_:)` to suspend the coroutine without blocking a thread
/// and resume it when the result is ready.
///
/// To launch a coroutine, use `CoroutineScheduler.startCoroutine(_:)`.
/// ```
/// //execute coroutine on the main thread
/// DispatchQueue.main.startCoroutine {
///
///     //extension that returns CoFuture<(data: Data, response: URLResponse)>
///     let dataFuture = URLSession.shared.dataTaskFuture(for: url)
///
///     //await result that suspends coroutine and doesn't block the thread
///     let data = try dataFuture.await().data
///
/// }
/// ```
///
/// The framework includes the implementation of this protocol for `DispatchQueue`
/// and you can easily make the same for other schedulers as well.
/// ```
/// extension OperationQueue: CoroutineScheduler {
///
///     public func scheduleTask(_ task: @escaping () -> Void) {
///         addOperation(task)
///     }
///
/// }
/// ```

/// 一个定义了如何执行任务的协议。
///
/// 该协议具有扩展方法，允许在当前调度器上启动协程。
/// 在协程内部，你可以使用诸如 `Coroutine.await(_:)`、`CoFuture.await()` 和 `CoroutineScheduler.await(_:)` 这样的方法来挂起协程，
/// 而不阻塞线程，并在结果准备就绪时恢复协程。
///
/// 要启动一个协程，使用 `CoroutineScheduler.startCoroutine(_:)` 方法。
/// ```
/// // 在主线程上执行协程
/// DispatchQueue.main.startCoroutine {
///
///     // 返回 CoFuture<(data: Data, response: URLResponse)> 的扩展
///     let dataFuture = URLSession.shared.dataTaskFuture(for: url)
///
///     // 等待结果，挂起协程，不阻塞线程
///     let data = try dataFuture.await().data
///
/// }
/// ```
///
/// 该框架已为 `DispatchQueue` 实现了该协议，
/// 你也可以很容易地为其他调度器做同样的实现。
/// ```
/// extension OperationQueue: CoroutineScheduler {
///
///     public func scheduleTask(_ task: @escaping () -> Void) {
///         addOperation(task)
///     }
///
/// }
/// ```

public protocol CoroutineScheduler {
    
    /// Performs the task at the next possible opportunity.
    /*
     开启一个协程任务的时候, 这个协程任务 resume 的时候, 以及这个协程任务 restart 的时候, 应该在哪个环境进行启动. 
     */
    func scheduleTask(_ task: @escaping () -> Void)
}

extension CoroutineScheduler {
    
    @inlinable internal func _startCoroutine(_ task: @escaping () -> Void) {
        SharedCoroutineDispatcher.default.execute(on: self, task: task)
    }
    
    /// Start a new coroutine on the current scheduler.
    ///
    /// As an example, with `Coroutine.await(_:)` you can wrap asynchronous functions with callbacks
    /// to synchronously receive its result without blocking the thread.
    /// ```
    /// //start new coroutine on the main thread
    /// DispatchQueue.main.startCoroutine {
    ///     //execute someAsyncFunc() and await result from its callback
    ///     let result = try Coroutine.await { someAsyncFunc(callback: $0) }
    /// }
    /// ```
    /// - Parameters:
    ///   - scope: `CoScope`to add coroutine to.
    ///   - task: The closure that will be executed inside coroutine. If the task throws an error, then the coroutine will be terminated.
    
    /// 在当前调度器上启动一个新的协程。
    ///
    /// 举个例子，你可以使用 Coroutine.await(_:) 包装带有回调的异步函数，
    /// 同步接收其结果，而不会阻塞线程。
    /// ```
    /// //在主线程上启动新的协程
    /// DispatchQueue.main.startCoroutine {
    ///     //执行 someAsyncFunc() 并等待其回调的结果
    ///     let result = try Coroutine.await { someAsyncFunc(callback: $0) }
    /// }
    /// ```
    ///
    /// - 参数:
    ///   - scope: 要添加协程的 `CoScope`。
    ///   - task: 在协程内部执行的闭包。如果任务抛出错误，则协程将被终止。

    public func startCoroutine(in scope: CoScope? = nil, task: @escaping () throws -> Void) {
        guard let scope = scope else { return _startCoroutine { try? task() } }
        _startCoroutine { [weak scope] in
            guard let coroutine = try? CoroutineSpace.current(),
                let completion = scope?.add(coroutine.cancel) else { return }
            // 前面可以认为是在准备环境.
            try? task()
            completion()
        }
    }
    
    /// Start a coroutine and await its result. Must be called inside other coroutine.
    ///
    /// This method allows to execute given task on other scheduler and await its result without blocking the thread.
    /// ```
    /// //start coroutine on the main thread
    /// DispatchQueue.main.startCoroutine {
    ///     //execute someSyncFunc() on global queue and await its result
    ///     let result = try DispatchQueue.global().await { someSyncFunc() }
    /// }
    /// ```
    /// - Parameter task: The closure that will be executed inside coroutine.
    /// - Throws: Rethrows an error from the task or throws `CoroutineError`.
    /// - Returns: Returns the result of the task.
    @inlinable public func await<T>(_ task: () throws -> T) throws -> T {
        try CoroutineSpace.current().await(on: self, task: task)
    }
    
    /// Starts a new coroutine and returns its future result.
    ///
    /// This method allows to execute a given task asynchronously inside a coroutine
    /// and returns `CoFuture` with its future result immediately.
    ///
    /// - Note: If you cancel this `CoFuture`, it will also cancel the coroutine that was started inside of it.
    ///
    /// ```
    /// //execute someSyncFunc() on global queue and return its future result
    /// let future = DispatchQueue.global().coroutineFuture { someSyncFunc() }
    /// //start coroutine on main thread
    /// DispatchQueue.main.startCoroutine {
    ///     //await result of future
    ///     let result = try future.await()
    /// }
    /// ```
    /// - Parameter task: The closure that will be executed inside the coroutine.
    /// - Returns: Returns `CoFuture` with the future result of the task.
    @inlinable public func coroutineFuture<T>(_ task: @escaping () throws -> T) -> CoFuture<T> {
        let promise = CoPromise<T>()
        _startCoroutine {
            if let coroutine = try? CoroutineSpace.current() {
                promise.whenCanceled(coroutine.cancel)
            }
            if promise.isCanceled { return }
            promise.complete(with: Result(catching: task))
        }
        return promise
    }
    
    /// Starts new coroutine that is receiving messages from its mailbox channel and returns its mailbox channel as a `Sender`.
    ///
    /// An actor coroutine builder conveniently combines a coroutine,
    /// the state that is confined and encapsulated into this coroutine,
    /// and a channel to communicate with other coroutines.
    ///
    /// - Note: If you cancel this `CoChannel`, it will also cancel the coroutine that was started inside of it.
    ///
    /// ```
    /// //Message types for actor
    /// enum CounterMessages {
    ///     case increment, getCounter(CoPromise<Int>)
    /// }
    ///
    /// let actor = DispatchQueue.global().actor(of: CounterMessages.self) { receiver in
    ///     var counter = 0
    ///     for message in receiver {
    ///         switch message {
    ///         case .increment:
    ///             counter += 1
    ///         case .getCounter(let promise):
    ///             promise.success(counter)
    ///         }
    ///     }
    /// }
    ///
    /// DispatchQueue.concurrentPerform(iterations: 100_000) { _ in
    ///     actor.offer(.increment)
    /// }
    ///
    /// let promise = CoPromise<Int>()
    /// promise.whenSuccess { print($0) }
    /// actor.offer(.getCounter(promise))
    /// actor.close()
    /// ```
    ///
    /// - Parameters:
    ///   - type: `CoChannel` generic type.
    ///   - bufferType: The type of channel buffer.
    ///   - body: The closure that will be executed inside coroutine.
    /// - Returns: `CoChannel.Sender` for sending messages to an actor.
    @inlinable public func actor<T>(of type: T.Type = T.self,
                                    bufferType: CoChannel<T>.BufferType = .unlimited,
                                    body: @escaping (CoChannel<T>.Receiver) throws -> Void)
        -> CoChannel<T>.Sender {
            let (receiver, sender) = CoChannel<T>(bufferType: bufferType).pair
            _startCoroutine {
                if let coroutine = try? CoroutineSpace.current() {
                    receiver.whenCanceled { [weak coroutine] in coroutine?.cancel() }
                }
                if receiver.isCanceled { return }
                try? body(receiver)
            }
            return sender
    }
    
}
