private protocol _CoFutureCancellable: AnyObject {
    func cancel()
}

/// Holder for a result that will be provided later.

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


public class CoFuture<Value> {
    
    @usableFromInline internal typealias _Result = Result<Value, Error>
    
    private var resultState: Int
    private var nodes: CallbackStack<_Result>
    private var _result: _Result?
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
        Coroutine.start {
            if let current = try? Coroutine.current() {
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
        // 如果, 已经赋值过了 Result, 直接返回.
        if atomicExchange(&resultState, with: 1) == 1 { return }
        _result = result
        parent = nil
        // 触发所有的回调函数.
        nodes.close()?.finish(with: result)
    }
    
    // MARK: - Callback
    
    @usableFromInline internal func addCallback(_ callback: @escaping (_Result) -> Void) -> Void {
        if !nodes.append(callback) { _result.map(callback) }
    }
    
    // MARK: - cancel
    
    /// Returns `true` when the current future is canceled.
    @inlinable public var isCanceled: Bool {
        // 特殊判断, 如果 result 是 failure, 并且是 cancel 的类型.
        // 这种设计很常见. Result 中做 Bool 区分, failure 中专门定义一个 case, 代表着主动取消.
        if case .failure(let error as CoFutureError)? = result {
            return error == .canceled
        }
        return false
    }
    
    /// Cancels the current future.
    public func cancel() {
        parent?.cancel() ?? setResult(.failure(CoFutureError.canceled))
    }
    
}
