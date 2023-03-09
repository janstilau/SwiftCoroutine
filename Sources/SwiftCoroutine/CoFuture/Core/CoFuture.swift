private protocol _CoFutureCancellable: AnyObject {
    func cancel()
}

/*
 这个 Future/Promise 应该是别的语言已经提出来的通用概念了.
 
 和 Promise 一样, Future 是状态盒子. 可以给这个状态盒子添加回调. 当状态改变之后, 会触发所有添加的回调.
 不同的是, 这个 Future 可以引起协程的 wait 操作.
 
 将 SetResult 暴露出去, 使得 Future 的构建, 和 Future 的状态 resolve 代码可以分开, 不用集中到构造过程中了.
 */
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
///  以上的写法, 就很像是 PromiseKit 里面的写法了. 将 Promise 的 Resolve 暴露出来, 这样就不用将所有的逻辑, 集中到构造函数里面了.
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
    
    private var nodes: CallbackStack<_Result> // 这里面存储的是回调闭包.
    private var resultState: Int // 是否完成的标志
    private var _result: Optional<_Result> // 完成的结果.
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
        // 最后, 还是会进行清理的.
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
        CoroutineStruct.start {
            if let current = try? CoroutineStruct.current() {
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
        if atomicExchange(&resultState, with: 1) == 1 { return }
        _result = result
        parent = nil
        // 触发了回调.
        nodes.close()?.finish(with: result)
    }
    
    // MARK: - Callback
    
    @usableFromInline internal func addCallback(_ callback: @escaping (_Result) -> Void) {
        // 这里和 Promise 的思想是一致的, 如果有结果了, 还是可以出发 callback.
        if !nodes.append(callback) { _result.map(callback) }
    }
    
    // MARK: - cancel
    
    /// Returns `true` when the current future is canceled.
    // 针对 cancel, 其实就是进行 error 和特定值进行比较.
    @inlinable public var isCanceled: Bool {
        if case .failure(let error as CoFutureError)? = result {
            return error == .canceled
        }
        return false
    }
    
    /// Cancels the current future.
    public func cancel() {
        // 会触发链式 cancel.
        parent?.cancel() ?? setResult(.failure(CoFutureError.canceled))
    }
    
}
