
/// The holder of uncompleted `CoCancellable` and coroutines.


/// `CoScope` helps to manage lifecycle of coroutines and `CoCancellable`, like `CoFuture` and `CoChannel`.
/// It keeps weak references on inner objects and cancels them on `cancel()` or deinit.
/// All completed objects are automaticaly removed from scope.
///
/// - Note: `CoScope` keeps weak references.


/// ```
/// let scope = CoScope()
/// let future = makeSomeFuture().added(to: scope)
///
/// queue.startCoroutine(in: scope) {
///     . . . some code . . .
///     let result = try future.await()
///     . . . some code . . .
/// }
///
/// let future2 = queue.coroutineFuture {
///     try Coroutine.delay(.seconds(5)) // imitate some work
///     return 5
/// }.added(to: scope)
///
/// //cancel all added futures and coroutines
/// scope.cancel()
/// ```

public final class CoScope {
    
    internal typealias Completion = () -> Void
    private var storage = Storage<Completion>()
    private var callbacks = CallbackStack<Void>()
    
    /// Initializes a scope.
    public init() {}
    
    /// Adds weak referance of `CoCancellable` to be canceled when the scope is being canceled or deinited.
    /// - Parameter item: `CoCancellable` to add.
    public func add(_ item: CoCancellable) {
        add {
            // 弱引用.
            [weak item] in
            // 当, Bag 生命周期结束的时候, 是 Item 的 cancel 被调用. 
            item?.cancel()   
        }.map(item.whenComplete)
        
        /*
         Optional 的 map, 就是如果 Optional 有值, 把该值抽取出来, 然后交给 Map 的参数. Map 的参数是一个回调.
         所以这里的含义就是, add {} 的返回值, 添加到 Item 的 whenComplete 中.
         也就是说, 如果 Item Complete 之后, 会自动执行.
         这个自动执行的就是, 将 Bag 中存储的进行去除. 也就是, Future 完结后, 就不需要 Bag 使用生命周期来维护 Future 的 cancel 操作了.
         */
    }
    
    internal func add(_ cancel: @escaping () -> Void) -> Completion? {
        if isCanceled { cancel(); return nil }
        let key = storage.append(cancel)
        if isCanceled { storage.remove(key)?(); return nil }
        
        return { [weak self] in self?.remove(key: key) }
    }
    
    private func remove(key: Storage<Completion>.Index) {
        storage.remove(key)
    }
    
    /// Returns `true` if the scope is empty (contains no `CoCancellable`).
    public var isEmpty: Bool {
        isCanceled || storage.isEmpty
    }
    
    // MARK: - cancel
    
    /// Returns `true` if the scope is canceled.
    public var isCanceled: Bool {
        callbacks.isClosed
    }
    
    /// Cancels the scope and all `CoCancellable` that it contains.
    public func cancel() {
        if isCanceled { return }
        completeAll()
        storage.removeAll()
    }
    
    private func completeAll() {
        callbacks.close()?.finish(with: ())
        storage.forEach { $0() }
    }
    
    /// Adds an observer callback that is called when the `CoScope` is canceled or deinited.
    /// - Parameter callback: The callback that is called when the scope is canceled or deinited.
    public func whenComplete(_ callback: @escaping () -> Void) {
        if !callbacks.append(callback) { callback() }
    }
    
    deinit {
        if !isCanceled { completeAll() }
        storage.free()
    }
    
}
