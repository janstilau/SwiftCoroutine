private protocol _CoFutureCancellable: AnyObject {
    func cancel()
}

/// Holder for a result that will be provided later.
///
/// `CoFuture` and its subclass `CoPromise` are the implementation of the Future/Promise approach.
/// They allow to launch asynchronous tasks and immediately return` CoFuture` with its future results.
/// The available result can be observed by the `whenComplete()` callback
/// or by `await()` inside a coroutine without blocking a thread.
///
/// ```
/// func makeFutureOne(args) -> CoFuture<Response> {
///     let promise = CoPromise<Response>()
///     someAsyncFuncWithCallback { response in
///         . . . do some work . . .
///         promise.success(response)
///     }
///     return promise
/// }
///
/// func makeFutureTwo(args) -> CoFuture<Response> {
///     queue.coroutineFuture {
///         let future = makeFutureOne(args)
///         . . . do some work . . .
///         let response = try future.await()
///         . . . create result using response . . .
///         return result
///     }
///  }
///
/// func performSomeWork(args) {
///     let future = makeFutureTwo(args)
///     mainQueue.startCoroutine {
///         . . . do some work . . .
///         let result = try future.await()
///         . . . do some work using result . . .
///     }
/// }
/// ```
///
/// For coroutine error handling you can use standart `do-catch` statement or use `CoFuture` as an alternative.
///
/// ```
/// //execute coroutine and return CoFuture<Void> that we will use for error handling
/// DispatchQueue.main.coroutineFuture {
///     let result = try makeSomeFuture().await()
///     . . . use result . . .
/// }.whenFailure { error in
///     . . . handle error . . .
/// }
/// ```
///
/// Apple has introduced a new reactive programming framework `Combine`
/// that makes writing asynchronous code easier and includes a lot of convenient and common functionality.
/// We can use it with coroutines by making `CoFuture` a subscriber and await its result.
///
/// ```
/// //create Combine publisher
/// let publisher = URLSession.shared.dataTaskPublisher(for: url).map(\.data)
///
/// //execute coroutine on the main thread
/// DispatchQueue.main.startCoroutine {
///     //subscribe CoFuture to publisher
///     let future = publisher.subscribeCoFuture()
///
///     //await data without blocking the thread
///     let data: Data = try future.await()
/// }
/// ```

/// 一个稍后提供结果的结果持有者。
///
/// `CoFuture` 及其子类 `CoPromise` 是实现 Future/Promise 方法的工具。
/// 它们允许启动异步任务，并立即返回带有未来结果的 `CoFuture`。
/// 可以通过 `whenComplete()` 回调或在协程内部使用 `await()` 来观察到可用的结果，而不会阻塞线程。
///
/// ```
/// func makeFutureOne(args) -> CoFuture<Response> {
///     let promise = CoPromise<Response>()
///     someAsyncFuncWithCallback { response in
///         . . . 进行一些工作 . . .
///         promise.success(response)
///     }
///     return promise
/// }
///
/// func makeFutureTwo(args) -> CoFuture<Response> {
///     queue.coroutineFuture {
///         let future = makeFutureOne(args)
///         . . . 进行一些工作 . . .
///         let response = try future.await()
///         . . . 使用响应创建结果 . . .
///         return result
///     }
///  }
///
/// func performSomeWork(args) {
///     let future = makeFutureTwo(args)
///     mainQueue.startCoroutine {
///         . . . 进行一些工作 . . .
///         let result = try future.await()
///         . . . 使用结果进行一些工作 . . .
///     }
/// }
/// ```
///
/// 对于协程错误处理，可以使用标准的 `do-catch` 语句，也可以使用 `CoFuture` 作为替代方法。
///
/// ```
/// //执行协程并返回 CoFuture<Void>，我们将用它进行错误处理
/// DispatchQueue.main.coroutineFuture {
///     let result = try makeSomeFuture().await()
///     . . . 使用结果 . . .
/// }.whenFailure { error in
///     . . . 处理错误 . . .
/// }
/// ```
///
/// Apple 引入了一个新的响应式编程框架 `Combine`，它使编写异步代码更容易，并包含许多方便和常见的功能。
/// 我们可以通过将 `CoFuture` 作为订阅者来使用它，并等待其结果。
///
/// ```
/// //创建 Combine 发布者
/// let publisher = URLSession.shared.dataTaskPublisher(for: url).map(\.data)
///
/// //在主线程上执行协程
/// DispatchQueue.main.startCoroutine {
///     //将 CoFuture 订阅到发布者
///     let future = publisher.subscribeCoFuture()
///
///     //在不阻塞线程的情况下等待数据
///     let data: Data = try future.await()
/// }
/// ```

public class CoFuture<Value> {
    
    // 可能发生错误, 所以, 直接里面的 _result 是 Result类型的.
    @usableFromInline internal typealias _Result = Result<Value, Error>
    
    private var resultState: Int
    private var nodes: CallbackStack<_Result>
    // 没有结果, 和发生错误是两回事.
    private var _result: Optional<_Result>
    private unowned(unsafe) var parent: _CoFutureCancellable?
    
    @usableFromInline internal init(_result: _Result?) {
        if let result = _result {
            self._result = result
            resultState = 1
            nodes = CallbackStack(isFinished: true)
        } else {
            self._result = nil
            resultState = 0
            nodes = CallbackStack()
        }
    }
    
    deinit {
        if nodes.isEmpty { return }
        // 如果, Future 没有触发 result 的确定, 就认为是取消了. 
        nodes.finish(with: .failure(CoFutureError.canceled))
    }
}

extension CoFuture: _CoFutureCancellable {
    
    internal convenience init<T>(parent: CoFuture<T>) {
        self.init(_result: nil)
        self.parent = parent
    }
    
    /// Initializes a future that invokes a promise closure.
    /// ```
    /// func someAsyncFunc(callback: @escaping (Result<Int, Error>) -> Void) { ... }
    ///
    /// let future = CoFuture(promise: someAsyncFunc)
    /// ```
    /// - Parameter promise: A closure to fulfill this future.
    @inlinable public convenience init(promise: (@escaping (Result<Value, Error>) -> Void) -> Void) {
        self.init(_result: nil)
        promise(setResult)
    }

    /// Starts a new coroutine and initializes future with its result.
    ///
    /// - Note: If you cancel this `CoFuture`, it will also cancel the coroutine that was started inside of it.
    ///
    /// ```
    /// func sum(future1: CoFuture<Int>, future2: CoFuture<Int>) -> CoFuture<Int> {
    ///     CoFuture { try future1.await() + future2.await() }
    /// }
    /// ```
    /// - Parameter task: The closure that will be executed inside the coroutine.
    @inlinable public convenience init(task: @escaping () throws -> Value) {
        self.init(_result: nil)
        CoroutineSpace.start {
            if let current = try? CoroutineSpace.current() {
                self.whenCanceled(current.cancel)
            }
            self.setResult(Result(catching: task))
        }
    }
    
    /// Initializes a future with result.
    /// - Parameter result: The result provided by this future.
    @inlinable public convenience init(result: Result<Value, Error>) {
        self.init(_result: result)
    }
    
    // MARK: - result
    
    /// Returns completed result or nil if this future has not been completed yet.
    public var result: Result<Value, Error>? {
        nodes.isClosed ? _result : nil
    }
    
    @usableFromInline internal func setResult(_ result: _Result) {
        // 返回 1, 就是原来就有值了.
        if atomicExchange(&resultState, with: 1) == 1 { return }
        _result = result
        parent = nil
        nodes.close()?.finish(with: result)
    }
    
    // MARK: - Callback
    
    @usableFromInline internal func addCallback(_ callback: @escaping (_Result) -> Void) {
        if !nodes.append(callback) { _result.map(callback) }
    }
    
    // MARK: - cancel

    /// Returns `true` when the current future is canceled.
    @inlinable public var isCanceled: Bool {
        if case .failure(let error as CoFutureError)? = result {
            return error == .canceled
        }
        return false
    }
    
    /// Cancels the current future.
    public func cancel() {
        // parent 唯一的作用就是这里, 当自己取消的时候, 触发父节点的取消.
        // cancel, 就是 Future 封箱的过程. 而这个封箱的过程, 会触发各种回调. 
        parent?.cancel() ?? setResult(.failure(CoFutureError.canceled))
    }
    
}
