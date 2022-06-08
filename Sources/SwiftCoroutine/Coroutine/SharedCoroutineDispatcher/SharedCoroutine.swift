
private var idGenerator: Int = 0


internal final class SharedCoroutine {
    
    internal typealias CompletionState = SharedCoroutineQueue.CompletionState
    
    private struct CachedStackBuffer {
        let startPointer: UnsafeMutableRawPointer
        let stackSize: Int
    }
    
    // 这三项, 仅仅在这里进行一个索引. 并不是在 SharedCoroutine 进行的生成.
    internal let dispatcher: SharedCoroutineDispatcher // 这是一个定值, 就是一个单例对象.
    
    weak var superCoroutine: SharedCoroutine? {
        didSet {
        }
    }
    var level: Int {
        if let superCoroutine = superCoroutine {
            return superCoroutine.level + 1
        } else {
            return 0
        }
    }
    /*
     将协程 start, resume 的动作进行调度.
     可以看做是协程运行环境的管理. 协程和线程, 没有必然的关系.
    */
    private(set) var scheduler: CoroutineScheduler
    
    internal let queue: SharedCoroutineQueue
    
    private var routeState: Int = .running
    // 在每次 suspend 的时候, 将当前协程的状态, 存储到了 environment 里面.
    private var environment: UnsafeMutablePointer<CoroutineContext.SuspendData>!
    private var stackBuffer: CachedStackBuffer!
    private var isCanceled = 0
    private var awaitTag = 0
    
    var id: Int = 0
    
    internal init(dispatcher: SharedCoroutineDispatcher,
                  queue: SharedCoroutineQueue,
                  scheduler: CoroutineScheduler) {
        self.dispatcher = dispatcher
        self.queue = queue
        self.scheduler = scheduler
        id = idGenerator
        idGenerator += 1
    }
    
    // MARK: - Actions
    
    internal func start() -> CompletionState {
        performAsCurrent {
            return perform {
                print("id: \(self.id) level: \(self.level) 在 queue: \(queue.id) 上启动. 当前线程 \(Thread.current)")
                return queue.context.start()
            }
        }
    }
    
    internal func resume() -> CompletionState {
        performAsCurrent {
            return perform {
                print("id: \(self.id) level: \(self.level) 在 queue: \(queue.id) 上恢复. 当前线程 \(Thread.current)")
                return queue.context.resume(from: environment.pointee._jumpBuffer)
            }
        }
    }
    
    // 真正的协程恢复的地方.
    private func resumeContext() -> CompletionState {
        perform {
            // __assemblySave(env, contextJumpBuffer, .suspended) == .finished
            queue.context.resume(from: environment.pointee._jumpBuffer)
        }
    }
    
    // 该函数, 返回当前协程的状态.
    /*
     queue.context.resume
     queue.context.start
     
     actionWithReturnIsCoroutionEnded 如果返回是 true, 那就是协程的任务, 已经跑完了. 协程进入完结状态.
     否则, 应该根据 routeState 来返回当前协程任务的完成状态.
     */
    private func perform(_ actionWithReturnIsCoroutionEnded: () -> Bool) -> CompletionState {
        if actionWithReturnIsCoroutionEnded() {
            return .finished
        }
        
        // 如果, 上面的 Block 没有返回 true, 就是协程进入到暂停的状态了.
        while true {
            switch routeState {
                // 在这里, 才真正的将自己的状态, 修改为 suspended.
            case .suspending:
                if atomicCAS(&routeState, expected: .suspending, desired: .suspended) {
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
        if environment == nil {
            environment = .allocate(capacity: 1)
            environment.initialize(to: .init())
        }
        print("id: \(self.id) level: \(self.level) 在 queue: \(queue.id) 上暂停. 当前线程 \(Thread.current)")
        queue.context.suspend(to: environment)
    }
    
    // MARK: - Stack
    
    // 通过在每一个协程里面, 存储 stackBuffer 达到了调用堆栈保存的功能.
    internal func saveStack() {
        let size = environment.pointee._stackTop.distance(to: queue.context.stackBottom)
        let stack = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        // 不会吧所有的都存储下来, 只是把当前使用到的栈顶存储下来.
        stack.copyMemory(from: environment.pointee._stackTop, byteCount: size)
        stackBuffer = .init(startPointer: stack, stackSize: size)
    }
    
    internal func restoreStack() {
        environment.pointee._stackTop.copyMemory(from: stackBuffer.startPointer, byteCount: stackBuffer.stackSize)
        stackBuffer.startPointer.deallocate()
        stackBuffer = nil
    }
    
    deinit {
        environment?.pointee._jumpBuffer.deallocate()
        environment?.deallocate()
    }
    
    func dump() {
        print("Id: \(self.id), queue: \(self.queue), thread: \(Thread.current)")
    }
    
}

// 真正的, 实现了 CoroutineProtocol 的实现类.
// 目前在类库里面, 只有这样的一个类, 实现了 CoroutineProtocol 的抽象.
extension SharedCoroutine: CoroutineProtocol {
    
    // Await, 参数是一个异步函数的触发器.
    // 这个异步函数, 接受一个回调, 来作为自己的 CompletionHandler
    
    /*
     { callback in
     URLSession.shared.dataTask(with: url, completionHandler: callback).resume()
     }
     */
    // 最最核心的方法, Future 里面的 await, 也是通过该方法来实现的.
    internal func await<T>(_ asyncTrigger: (@escaping (T) -> Void) -> Void)
    throws -> T {
        if isCanceled == 1 { throw CoroutineError.canceled }
        routeState = .suspending
        
        let tagWhenTrigger = awaitTag
        var result: T!
        // 在这里, 使用异步 API 触发了异步函数.
        // 只有在异步 API 的回调里面, 才进行 resume 处理.
        
        /*
         原本的 asyncTrigger 的回调, 是进行业务处理.
         现在变为了, 进行值的赋值, 然后进行协程的唤醒.
         可以使用信号量的同步取值逻辑来思考这一块.  asyncTrigger 的回调, 是用来进行取值的, 在异步函数取到值之后, 进行赋值的操作, 然后唤醒原来的流程.
         */
        
        /*
         Swift 的续体, 应该就是在 asyncTrigger 的回调中做文章.
         将, resumeIfSuspended 的逻辑, 封装到了续体的 resume 方法的内部.
         
         如果自己设计, 应该就是将 result 改为 Result<T> 的类型, 然后将 Result 的赋值动作封装到 续体 的内部.
         在  suspend() 后, 判断 Result 的 Type. 如果是 error 就 throw, 如果是正常值, 就 return .
         
         协程, 这种保证了顺序一定是线性的, 和同步函数一样, 让代码逻辑变得简单明了.
         */
        /*
         asyncTrigger 可能不是异步函数, 所以, 它的回调可能会直接就在当前线程里面执行完毕了.
         */
        asyncTrigger { value in
            while true {
                // 如果, id 已经改变了, 那么就没有必要进行 result 的赋值了.
                guard self.awaitTag == tagWhenTrigger else { return }
                
                // 唯一进行 awaitTag 改变的地方, 就是这里了.
                if atomicCAS(&self.awaitTag,
                             expected: tagWhenTrigger,
                             desired: tagWhenTrigger + 1) { break }
            }
            // 在 asyncTrigger 的异步回调里面, 是做真正的值的提取.
            // 所以, 实际上还是使用了以后的异步触发机制. 只是现在变为了, 只有异步返回之后, 才能进行后续的操作.
            result = value
            
            // 这里有点类似于条件锁, 在 commit 线程, 进行 lock 处理, 然后在异步 callback 中, 进行 unlock 的操作.
            // 这样, commit 线程才能继续进行.
            // 在异步操作完成之后, 进行调度.
            
            
            // asyncTrigger 的回调, 除了进行值的读取外, 最最重要的, 就是这里开启了协程的重新调度. 
            self.resumeIfSuspended()
        }
        
        if routeState == .suspending {
            // 在异步函数, 触发之后, 进行调度.
            // 如果上面的 asyncTrigger 不是异步函数, 而是一个同步函数, 那么 resumeIfSuspended 其实会将 routeState 的状态修改为 running, 这里也就不需要 suspend()
            suspend()
        }
        
        if isCanceled == 1 { throw CoroutineError.canceled }
        return result
    }
    
    internal func await<T>(on scheduler: CoroutineScheduler,
                           task: () throws -> T)
    throws -> T {
        if isCanceled == 1 { throw CoroutineError.canceled }
        let currentScheduler = self.scheduler
        setScheduler(scheduler)
        defer { setScheduler(currentScheduler) }
        if isCanceled == 1 { throw CoroutineError.canceled }
        return try task()
        
    }
    
    private func setScheduler(_ scheduler: CoroutineScheduler) {
        self.scheduler = scheduler
        routeState = .restarting
        suspend()
    }
    
    internal func cancel() {
        // 将, 标志位设置为 isCanceled = true. 然后重新调度自己.
        // 在上面 await 的  suspend() 之后, 第一条就是判断自己是不是已经取消了. 如果是, 则直接抛出错误.
        // 所以, 实际上, 取消操作, 一定会引起协程的重新调度的. 
        atomicStore(&isCanceled, value: 1)
        resumeIfSuspended()
    }
    
    private func resumeIfSuspended() {
        while true {
            // 使用, atomicCAS 进行值的替换.
            // 不太明白, atomic_compare_exchange_strong 这样的意义在哪里.
            // 不过, 在协程的概念里面, 确实是听到了, 不要进行上锁, 而是进行原子操作的这样的语句.
            switch routeState {
            case .suspending:
                // 如果, await 中传入的是一个同步 asyncTrigger, 也就是不需要暂停当前的协程.
                // 这样修改了之后, await 中的代码不会真正的触发 suspend 的逻辑, 所以整个协程, 其实是不会暂停运行的. 
                if atomicCAS(&routeState, expected: .suspending, desired: .running) { return }
            case .suspended:
                if atomicCAS(&routeState, expected: .suspended, desired: .running) {
                    return queue.resume(coroutine: self)
                }
            default:
                return
            }
        }
    }
}

// 可以使用 Int 来当做状态值, 只是, 需要显式的进行特殊值的预先构建.
fileprivate extension Int {
    static let running = 0
    static let suspending = 1
    static let suspended = 2
    static let restarting = 3
}
