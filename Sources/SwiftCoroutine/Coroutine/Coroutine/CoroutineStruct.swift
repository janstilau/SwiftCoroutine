import Dispatch

// ImmediateScheduler 真正的调度方面的实现, 就是直接调用.
// 但是还有大量的逻辑, 是写在了 CoroutineScheduler 里面.
// 再次强调了, 对于 swift 的 protocol 来说, 可以当做是一个抽象基类来进行看待.
@usableFromInline internal struct ImmediateScheduler: CoroutineScheduler {
    
    @usableFromInline init() {}
    @inlinable func scheduleTask(_ task: @escaping () -> Void) { task() }
    
}

/// Additional struct with utility methods to work with coroutines.
///
/// - Important: All `await()` methods must be called inside a coroutine.
///
/// To check if inside a coroutine, use `Coroutine.isInsideCoroutine`.
/// If you call `await()` outside the coroutine, the precondition inside these methods will fail, and you'ill get an error.
/// In -Ounchecked builds, where preconditions are not evaluated to avoid any crashes,
/// a thread-blocking mechanism is used for waiting the result.
///
public struct CoroutineStruct {
    
    /// Returns `true` if this property is called inside a coroutine.
    /// ```
    /// func awaitSomeData() throws -> Data {
    ///     //check if inside a coroutine
    ///     guard Coroutine.isInsideCoroutine else { throw . . . some error . . . }
    ///     try Coroutine.await { . . . return some data . . . }
    /// }
    /// ```
    @inlinable public static var isInsideCoroutine: Bool {
        currentPointer != nil
    }
    
    /*
     协程里面, 还是可以开启另外的一个协程的.
     这里不像是 await task, 只是开启了一个任务, 当前协程不会等下一个协程结束的. 
     */
    /// Starts a new coroutine.
    /// - Parameter task: The closure that will be executed inside coroutine.
    @inlinable public static func start(_ task: @escaping () throws -> Void) {
        ImmediateScheduler().startCoroutine(task: task)
    }
    
    // MARK: - await
    
    /// Suspends a coroutine and resumes it on callback. Must be called inside a coroutine.
    /// ```
    /// queue.startCoroutine {
    ///     try Coroutine.await { callback in
    ///         someAsyncFunc { callback() }
    ///     }
    /// }
    /// ```
    /// - Parameter callback: The callback to resume coroutine.
    /// - Throws: `CoroutineError`.
    @inlinable public static func await(_ callback: (@escaping () -> Void) -> Void) throws {
        try current().await { completion in callback { completion(()) } }
    }
    
    /// Suspends a coroutine and resumes it on callback.
    /// ```
    /// queue.startCoroutine {
    ///     let result = try Coroutine.await { callback in
    ///         someAsyncFunc { result in callback(result) }
    ///     }
    /// }
    /// ```
    /// - Parameter callback: The callback for resuming a coroutine. Must be called inside a coroutine.
    /// - Returns: The result which is passed to callback.
    /// - Throws: `CoroutineError`.
    @inlinable public static func await<T>(_ callback: (@escaping (T) -> Void) -> Void) throws -> T {
        try current().await(callback)
    }
    
    /// Suspends a coroutine and resumes it on callback. Must be called inside a coroutine.
    /// ```
    /// queue.startCoroutine {
    ///     let (a, b) = try Coroutine.await { callback in
    ///         someAsyncFunc(callback: callback)
    ///     }
    /// }
    /// ```
    /// - Parameter callback: The callback для resume coroutine.
    /// - Returns: The result which is passed to callback.
    /// - Throws: `CoroutineError`.
    @inlinable public static func await<T, N>(_ callback: (@escaping (T, N) -> Void) -> Void) throws -> (T, N) {
        try current().await { completion in callback { a, b in completion((a, b)) } }
    }
    
    /// Suspends a coroutine and resumes it on callback.
    /// ```
    /// queue.startCoroutine {
    ///     let (a, b, c) = try Coroutine.await { callback in
    ///         someAsyncFunc(callback: callback)
    ///     }
    /// }
    /// ```
    /// - Parameter callback: The callback для resume coroutine. Must be called inside a coroutine.
    /// - Returns: The result which is passed to callback.
    /// - Throws: `CoroutineError`.
    /*
     try Coroutine.await { callback in
     let url = URL.init(string: "https://www.baidu.com")!
     URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
     }
     */
    @inlinable public static func await<T, N, M>(_ asyncAction: (@escaping (T, N, M) -> Void) -> Void) throws -> (T, N, M) {
        /*
         asyncAction 用来触发异步操作, 他需要一个 三个参数的闭包, 来进行异步操作返回值的处理.
         这个闭包在 wait 中提供了.
         */
        try current().await { completion in asyncAction { a, b, c in completion((a, b, c)) } }
    }
    
    // MARK: - delay
    
    /// Suspends a coroutine for a certain time.  Must be called inside a coroutine.
    /// ```
    /// queue.startCoroutine {
    ///     while !someCondition() {
    ///         try Coroutine.delay(.seconds(1))
    ///     }
    /// }
    /// ```
    /// - Parameter time: The time interval for which a coroutine will be suspended.
    /// - Throws: `CoroutineError`.
    @inlinable public static func delay(_ time: DispatchTimeInterval) throws {
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + time)
        defer { timer.cancel() }
        do {
            try self.await {
                timer.setEventHandler(handler: $0)
                timer.start()
            }
        } catch {
            timer.start()
            throw error
        }
    }
    
}

// 这就是一个工具类, current 返回的只是 SharedCoroutine.
// 所以这个工具类里面, 都是静态方法. 
extension CoroutineStruct {
    
    // 在刚开始, 是没有这个值的. 这个值只会在上面 performAsCurrent 中进行赋值.
    @inlinable internal static var currentPointer: UnsafeMutableRawPointer? {
        pthread_getspecific(.coroutine)
    }
    
    @inlinable internal static func current() throws -> CoroutineProtocol {
        if let pointer = currentPointer,
           let coroutine = Unmanaged<AnyObject>.fromOpaque(pointer)
            .takeUnretainedValue() as? CoroutineProtocol {
            return coroutine
        }
        // 一定要在当前的 Thread 中进行 CoroutineProtocol 的赋值.
        // 因为实际上, 协程是要进行自己调用环境的单独存储的, 如果没有打造这个环境, 是不应该进行协程的逻辑的触发的.
        throw CoroutineError.calledOutsideCoroutine
    }
    
}

extension CoroutineStruct {
    
    @usableFromInline internal struct StackSize {
        internal let size: Int
    }
}

extension CoroutineStruct.StackSize {
    
    internal static let recommended = CoroutineStruct.StackSize(size: 192 * 1024)
    
    internal static func pages(_ number: Int) -> CoroutineStruct.StackSize {
        .init(size: number * .pageSize)
    }
    
}
