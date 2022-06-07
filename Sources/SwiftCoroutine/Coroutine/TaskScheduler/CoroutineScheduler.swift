

/// A protocol that defines how to execute a task.
///
/// This protocol has extension methods that allow to launch coroutines on a current scheduler.
/// Inside the coroutine you can use such methods as `Coroutine.await(_:)`, `CoFuture.await()`,
/// and `CoroutineScheduler.await(_:)` to suspend the coroutine without blocking a thread
/// and resume it when the result is ready.

// 
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
///
///

// 调度器的概念, 和 Combine, Rx 是一套思想.
// 各种的操作, 都是在 extension 中添加的.
public protocol CoroutineScheduler {
    
    /// Performs the task at the next possible opportunity.
    /*
     scheduler.scheduleTask {
         self.getFreeQueue().start(dispatcher: self,
                                   scheduler: scheduler,
                                   task: coroutionStartTask)
     }
     coroutine.scheduler.scheduleTask {
         // 在 resume 的时候, scheduleTask 进行了调度.
         self.complete(with: coroutine.resume())
     }
     coroutine.scheduler.scheduleTask {
         // 在 resume 的时候, scheduleTask 进行了调度.
         self.complete(with: self.coroutine.resume())
     }
     
     就和 Combine 中的 Scheduler 的概念一样的, Scheduler 起到的作用是, 将后续的操作, 置身到对应的环境中.
     在 Combine 里面, 这会是在创建响应链条的时候的环境, 以及节点之间传递数据的环境.
     
     而在 Coroutine 中, 则是, coroution 启动的环境, 以及 coroution 进行 resume 的环境.
     如果, 这个 CoroutineScheduler 是一个 DispatchQueue, 那么真正的 Resume, Start 的线程环境, 其实是不能够确定的.
     
     Coroution 中, 保存了完成的执行环境, 也就是 PC 寄存器的值以及其他的寄存器的值, 以及完整的调用堆栈, 所以其实 Coroutine 其实是不强依赖于线程的.
     
     这和 Swfit Async,Await 的概念是一致的, await 的前后环境, 有可能不在一个线程环境呢了, 这一定要谨记.
     */
    func scheduleTask(_ task: @escaping () -> Void)
    
}

// CoroutineScheduler 只有这里的一个分类.
extension CoroutineScheduler {
    
    /*
     _startCoroutine 就是一个标识. 标明, task 内的执行, 是在一个协程环境下.
     */
    @inlinable internal func _startCoroutine(_ task: @escaping () -> Void) {
        SharedCoroutineDispatcher.default.executeCoroutionStart(on: self,
                                                                coroutionStartTask: task)
    }
    
    /// Start a new coroutine on the current scheduler.
    ///
    /// As an example, with `Coroutine.await(_:)` you can wrap asynchronous functions with callbacks
    /// to synchronously receive its result without blocking the thread.
    
    //
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
    public func startCoroutine(in scope: CoScope? = nil, task: @escaping () throws -> Void) {
        guard let scope = scope else { return _startCoroutine { try? task() } }
        _startCoroutine { [weak scope] in
            guard let coroutine = try? Coroutine.current(),
                let completion = scope?.add(coroutine.cancel) else { return }
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
    
    /*
     当前的协程, 使用 self scheduler 来去处理 task 的任务.
     然后恢复到原来的 scheduler 继续后续的任务.
     */
    @inlinable public func await<T>(_ task: () throws -> T) throws -> T {
        try Coroutine.current().await(on: self, task: task)
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
            if let coroutine = try? Coroutine.current() {
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
                if let coroutine = try? Coroutine.current() {
                    receiver.whenCanceled { [weak coroutine] in coroutine?.cancel() }
                }
                if receiver.isCanceled { return }
                try? body(receiver)
            }
            return sender
    }
    
}
