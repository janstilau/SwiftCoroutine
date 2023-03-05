
// 这个类, 是协程函数的真正体现. 
internal final class SharedCoroutine {
    
    internal typealias CompletionState = SharedCoroutineQueue.CompletionState
    
    private struct StackBuffer {
        let stack: UnsafeMutableRawPointer
        let size: Int
    }
    private var stackBuffer: StackBuffer!
    private var suspenEnvironment: UnsafeMutablePointer<CoroutineContext.SuspendData>!
    
    internal let dispatcher: SharedCoroutineDispatcher
    internal let queue: SharedCoroutineQueue
    private(set) var scheduler: CoroutineScheduler
    private var state: Int = .running
        private var isCanceled = 0
    private var completionInvokeOnlyOnceTag = 0
    
    internal init(dispatcher: SharedCoroutineDispatcher, queue: SharedCoroutineQueue, scheduler: CoroutineScheduler) {
        self.dispatcher = dispatcher
        self.queue = queue
        self.scheduler = scheduler
    }
    
    // MARK: - Actions
    
    internal func start() -> CompletionState {
        performAsCurrent { perform(queue.context.start) }
    }
    
    internal func resume() -> CompletionState {
        performAsCurrent(resumeContext)
    }
    
    private func resumeContext() -> CompletionState {
        perform { queue.context.resume(from: suspenEnvironment.pointee.jumpBufferEnv) }
    }
    
    private func perform(_ block: () -> Bool) -> CompletionState {
        if block() { return .finished }
        while true {
            switch state {
            case .suspending:
                if atomicCAS(&state, expected: .suspending, desired: .suspended) {
                    return .suspended
                }
            case .running:
                return resumeContext()
            case .restarting:
                return .restarting
            default:
                return .suspended
            }
        }
    }
    
    private func suspend() {
        if suspenEnvironment == nil {
            // 使用 alloc 进行内存的分配操作.
            suspenEnvironment = .allocate(capacity: 1)
            // 使用 initialize 将这块内存, 分配给参数的这个值. 参数的这个值, 如果是引用类型, 会加入到 swift 的内存管理策略中.
            /*
             The destination memory must be uninitialized or the pointer’s Pointee must be a trivial type. After a call to initialize(to:), the memory referenced by this pointer is initialized. Calling this method is roughly equivalent to calling initialize(repeating:count:) with a count of 1.
             */
            suspenEnvironment.initialize(to: .init())
        }
        // 将, 当前的协程运行信息, 存储到了 environment 中, 然后返回到其他的协程任务中.
        queue.context.suspend(to: suspenEnvironment)
    }
    
    // MARK: - Stack
    
    internal func saveStack() {
        let size = suspenEnvironment.pointee.sp.distance(to: queue.context.stackTop)
        let stack = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        stack.copyMemory(from: suspenEnvironment.pointee.sp, byteCount: size)
        // 在这里, 进行了当前的堆栈数据的存储.
        stackBuffer = .init(stack: stack, size: size)
    }
    
    internal func restoreStack() {
        suspenEnvironment.pointee.sp.copyMemory(from: stackBuffer.stack, byteCount: stackBuffer.size)
        stackBuffer.stack.deallocate()
        stackBuffer = nil
    }
    
    deinit {
        suspenEnvironment?.pointee.jumpBufferEnv.deallocate()
        suspenEnvironment?.deallocate()
    }
}

extension SharedCoroutine: CoroutineProtocol {
    
    // T 会是一个 Tuple.
    internal func await<T>(_ asyncActionNeedCompletion: (@escaping (T) -> Void) -> Void) throws -> T {
        if isCanceled == 1 { throw CoroutineError.canceled }
        state = .suspending
        let tag = completionInvokeOnlyOnceTag
        var result: T!
        // 出发了异步操纵, 然后在异步操作的回调里面, 恢复了下方 syspend 住的协程.
        asyncActionNeedCompletion { value in
            while true {
                // 这里我猜测, 是为了让闭包只触发一次.
                // 不然没有太多的意义.
                // awaitTag 是一个 private 的值, 只会使用 atomicCAS 这个方式进行修改.
                guard self.completionInvokeOnlyOnceTag == tag else { return }
                if atomicCAS(&self.completionInvokeOnlyOnceTag, expected: tag, desired: tag + 1) { break }
            }
            // 在这里, 进行了 result 的值的确认.
            // 然后进行 resume. resume 使得协程可以在 suspend 之后继续进行.
            // 所以就算是有着异步行为, 在异步 completion 里面才能确定 result 的值, 但是这个函数还是可以达到同步函数的效果.
            // 底层的原理, 就是协程切换.
            result = value
            self.resumeIfSuspended()
        }
        // 这里的 suspend 操作, 会让整个函数的调用暂停.
        if state == .suspending { suspend() }
        if isCanceled == 1 { throw CoroutineError.canceled }
        return result
    }
    
    internal func await<T>(on scheduler: CoroutineScheduler, task: () throws -> T) throws -> T {
        if isCanceled == 1 { throw CoroutineError.canceled }
        let currentScheduler = self.scheduler
        setScheduler(scheduler)
        defer { setScheduler(currentScheduler) }
        if isCanceled == 1 { throw CoroutineError.canceled }
        return try task()
        
    }
    
    private func setScheduler(_ scheduler: CoroutineScheduler) {
        self.scheduler = scheduler
        state = .restarting
        suspend()
    }
    
    internal func cancel() {
        atomicStore(&isCanceled, value: 1)
        resumeIfSuspended()
    }
    
    private func resumeIfSuspended() {
        while true {
            switch state {
            case .suspending:
                // 如果异步操作, 其实不是异步操作, 直接触发了 completion 闭包.
                // 那么 state 就还是 .suspending 的状态. 那么直接讲 state 变为 running 状态.
                if atomicCAS(&state, expected: .suspending, desired: .running) { return }
            case .suspended:
                // 如果异步操作确实是异步的, 那么下方的 suspend 函数会被调用, 那么当前的状态就是 suspended.
                // 那么需要进行协程的恢复处理.
                if atomicCAS(&state, expected: .suspended, desired: .running) {
                    return queue.resume(coroutine: self)
                }
            default:
                return
            }
        }
    }
    
}

fileprivate extension Int {
    
    static let running = 0
    static let suspending = 1
    static let suspended = 2
    static let restarting = 3
    
}
