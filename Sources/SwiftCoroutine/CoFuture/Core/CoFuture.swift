
private protocol _CoFutureCancellable: AnyObject {
    func cancel()
}

// Holder for a result that will be provided later.

// 类似于, Combine 中的 Promise, 将值的确定逻辑, 放到了异步函数的回调里面.
// Future 里面, 可以存储各种的 Block 对象. 这些 Block 对象, 会在 Future 的 SetResult 被调用的时候, 统一的进行触发.
// 所以 Future 的行为模式, 和 Promise 是相似的.
// Future await 就是将当前的协程停止, 然后将协程恢复的逻辑, 添加到 Future Result Callback 中去. 这样, 当 Future 的值确定了之后, 可以触发协程的恢复.
// Future/Promise 是一种, 常见的异步结果使用的方式. 在各个语言里面, 都看见过相关的代码.
/// `CoFuture` and its subclass `CoPromise` are the implementation of the Future/Promise approach.
/// They allow to launch asynchronous tasks and immediately return` CoFuture` with its future results.
/// The available result can be observed by the `whenComplete()` callback
/// or by `await()` inside a coroutine without blocking a thread.


/// ```
/// func makeFutureOne(args) -> CoFuture<Response> {
///     let promise = CoPromise<Response>()
///     someAsyncFuncWithCallback { response in
///         . . . do some work . . .
///         promise.success(response)
///     }
///     直接就是将这个对象进行了返回, 在异步操作里面, 再对这个对象进行值的确定.
///     return promise
/// }

/// func makeFutureTwo(args) -> CoFuture<Response> {
///     queue.coroutineFuture {
///         let future = makeFutureOne(args)
///         . . . do some work . . .
///         使用 Await, 会触发协程的 suspend 操作.
///         let response = try future.await()
///         . . . create result using response . . .
///         return result
///     }
///  }


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

// 可以通过, 添加闭包回调的方式. 也可以使用 await, 判断 Result 的 Enum 值. 
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
    // 没太理解, 这个 Parent 究竟有什么作用. 目前来看, 是任何作用都没有.
    private unowned(unsafe) var parent: _CoFutureCancellable?
    
    /*
     根据 _result 是否有值, 来决定当前自己的状态.
     */
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
    
    //
    @inlinable public convenience init(promise: (@escaping (Result<Value, Error>) -> Void) -> Void) {
        self.init(_result: nil)
        // 直接将 setResult 函数传递了出去.
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
            // Result(catching: task) 这是, Result 这个类型的一个内置的构造函数.
            // 在 Result 的构造函数内部, 就会调用这个 task.
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
    // 在, setResult 中, 会触发所有的回调节点的触发. 所以, 可以根据 nodes 的状态, 来判断当前的状态.
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
    
    /*
     用, 响应链条的方式, 去思考 Future. 这就是一个 Promise 对象, 然后将 Promise 的值确定的回调, 进行存储.
     
     如果, 安插不进去了, 就是这个 Future 已经有值了.
     直接调用 callback, 传入当前的 result 值就好了.
     */
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
        // 如果, 有 Parent, 就是 Parent 的 cancel
        // 否则, 就是进行 SetResult 的调用.
        parent?.cancel() ?? setResult(.failure(CoFutureError.canceled))
    }
    
}
