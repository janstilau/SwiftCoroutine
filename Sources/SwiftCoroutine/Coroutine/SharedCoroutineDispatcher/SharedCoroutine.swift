
internal final class SharedCoroutine {
    
    internal typealias CompletionState = SharedCoroutineQueue.CompletionState
    
    private struct StackBuffer {
        let stack: UnsafeMutableRawPointer, size: Int
    }
    
    internal let dispatcher: SharedCoroutineDispatcher
    internal let queue: SharedCoroutineQueue
    
    //
    private(set) var scheduler: CoroutineScheduler
    
    private var state: Int = .running
    
    // 这里面, 存储了 jumpBuf, 和栈顶的地址.
    private var suspendEnv: UnsafeMutablePointer<CoroutineContext.SuspendData>!
    // 这里面, 存储了栈里面的数据
    private var stackBuffer: StackBuffer!
    
    // isCanceled 在每次环境变化的时候使用了. 
    private var isCanceled = 0
    private var awaitTag = 0
    
    internal init(dispatcher: SharedCoroutineDispatcher, queue: SharedCoroutineQueue, scheduler: CoroutineScheduler) {
        self.dispatcher = dispatcher
        self.queue = queue
        self.scheduler = scheduler
    }
  
    // MARK: - Actions
    
    internal func start() -> CompletionState {
        // context 的 start 方法, 只有这里使用了
        performAsCurrent { perform(queue.context.start) }
    }
    
    internal func resume() -> CompletionState {
        performAsCurrent(resumeContext)
    }
    
    private func resumeContext() -> CompletionState {
        perform { queue.context.resume(from: suspendEnv.pointee.jmpBuf) }
    }
    
    private func perform(_ block: () -> Bool) -> CompletionState {
        if block() { return .finished }
        
        while true {
            switch state {
            case .suspending:
                // 只有在这里, 将状态改写到了 suspended
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
    
    /*
     在 await 中触发.
     */
    private func suspend() {
        if suspendEnv == nil {
            suspendEnv = .allocate(capacity: 1)
            suspendEnv.initialize(to: .init())
        }
        queue.context.suspend(to: suspendEnv)
    }
    
    // MARK: - Stack
    
    // 这里怎么确保, stackTop 的值已经确定下来了呢.
    internal func saveStack() {
        /*
         从这里来看, 一个 queue 里面, 只有一个 CoroutineContext, 而这个 Context 的栈空间是共享的.
         这里只存储了, 当前任务所使用到的栈顶到栈底的空间. 存到了 stackBuffer 中. 
         */
        let size = suspendEnv.pointee.stackTop.distance(to: queue.context.stackBottom)
        let stack = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        stack.copyMemory(from: suspendEnv.pointee.stackTop, byteCount: size)
        stackBuffer = .init(stack: stack, size: size)
    }
    
    // 这里怎么确保, stackTop 的值已经确定下来了呢.
    internal func restoreStack() {
        suspendEnv.pointee.stackTop.copyMemory(from: stackBuffer.stack, byteCount: stackBuffer.size)
        stackBuffer.stack.deallocate()
        stackBuffer = nil
    }
    
    deinit {
        suspendEnv?.pointee.jmpBuf.deallocate()
        suspendEnv?.deallocate()
    }
    
}

extension SharedCoroutine: CoroutineProtocol {
    
    /*
     将自身暂停, 调用异步方法, 然后把将自己恢复的操作给异步方法, 由异步方法决定什么时候调用.
     */
    internal func await<T>(_ asyncAction: (@escaping (T) -> Void) -> Void) throws -> T {
        // 在这库里面, await 的时候, 如果已经 cancel, 就直接抛出异常了.
        if isCanceled == 1 { throw CoroutineError.canceled }
        state = .suspending
        let tag = awaitTag
        var result: T!
        // 这里, asyncAction 强引用了 routine 对象了.
        /*
         asyncAction 是一个异步函数, 在他的 Complete 的时候, 应该做点什么.
         这里就是, 应该唤起停止的协程.
         */
        asyncAction { value in
            while true {
                // 在 future 的 timeout 那里, 我们看到了这里的价值
                // 这里的闭包, 可能会触发好几次. 
                guard self.awaitTag == tag else { return }
                if atomicCAS(&self.awaitTag, expected: tag, desired: tag + 1) { break }
            }
            result = value
            self.resumeIfSuspended()
        }
        // 在这里, 把当前的运行环境存储一下, 然后暂停任务.
        if state == .suspending { suspend() }
        if isCanceled == 1 { throw CoroutineError.canceled }
        return result
    }
    
    internal func await<T>(on scheduler: CoroutineScheduler, 
                           task: () throws -> T) throws -> T {
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
        // 修改状态, 然后重新调度. 
        // 里面都没有使用锁, 而是使用了原子函数. 
        atomicStore(&isCanceled, value: 1)
        resumeIfSuspended()
    }
    
    // cancel 的话, 可以让协程恢复, 因为立马就要抛出异常了.
    // 完成了任务, 也可以协程恢复. 
    private func resumeIfSuspended() {
        while true {
            switch state {
            case .suspending:
                if atomicCAS(&state, expected: .suspending, desired: .running) { return }
            case .suspended:
                if atomicCAS(&state, expected: .suspended, desired: .running) {
                    return queue.resume(coroutine: self)
                }
            default:
                // 如果现在正在运行,根本就直接返回. 
                return
            }
        }
    }
    
}

// 使用原始的类型, 加上特定常量, 也是一种比较好的表现方式, 不比 enum 差.
fileprivate extension Int {
    static let running = 0
    static let suspending = 1
    static let suspended = 2
    static let restarting = 3
    
}
