
private var idGenerator: Int = 0

internal final class SharedCoroutineQueue: CustomStringConvertible {
    
    private struct Task {
        let scheduler: CoroutineScheduler, task: () -> Void
    }
    
    internal enum CompletionState: String {
        case finished, suspended, restarting
    }
    
    // 一个 Queue 里面, 一个 Context.
    internal let context: CoroutineContext
    private var queueCurrentCoroutine: SharedCoroutine! // 当前正在运行的协程对象.
    
    internal var isInFreeQueue = false
    private(set) var started = 0
    private var atomic = AtomicTuple()
    private var prepared = FifoQueue<SharedCoroutine>()
    
    public var id: Int = 0
    
    internal init(stackSize size: Int) {
        context = CoroutineContext(stackSize: size)
        id = idGenerator
        idGenerator += 1
    }
    
    internal func occupy() -> Bool {
        // update, 将对应的值, 改变成为参数中的值, 然后返回原来的值. 
        atomic.update(keyPath: \.0, with: .running) == .isFree
    }
    
    var description: String {
        return "SharedCoroutineQueue, QueueId: \(id)"
    }
    
    // MARK: - Actions
    
    // 外界调用, 进行协程开启的地方.
    internal func start(
        dispatcher: SharedCoroutineDispatcher,
        scheduler: CoroutineScheduler,
        task: @escaping () -> Void
    ) {
        queueCurrentCoroutine?.saveStack()
        queueCurrentCoroutine = SharedCoroutine(dispatcher: dispatcher, queue: self, scheduler: scheduler)
        started += 1
        context.coroutineMainTask = task
        self.complete(with: queueCurrentCoroutine.start())
    }
    
    // 外部调用, 进行协程恢复的地方.
    internal func resume(coroutine: SharedCoroutine) {
        let (state, _) = atomic.update { state, count in
            if state == .isFree {
                return (.running, count)
            } else {
                return (.running, count + 1)
            }
        }.old
        
        // 如果, 当前正在进行进行协程处理. 不会立马触发传入的新的协程对象.
        // prepared 会存储所有等待重新调用的协程对象.
        state == .isFree ? resumeOnQueue(coroutine) : prepared.push(coroutine)
    }
    
    private func resumeOnQueue(_ coroutine: SharedCoroutine) {
        if self.queueCurrentCoroutine !== coroutine {
            // 原有协程的状态存储.
            self.queueCurrentCoroutine?.saveStack()
            // 新来的协程的恢复.
            coroutine.restoreStack()
            self.queueCurrentCoroutine = coroutine
        }
        coroutine.scheduler.scheduleTask {
            /*
             调度之后, 可能会出现线程的切换.
             resume 会记录, 切换之后的线程的当前状态, 所以跳转会线程主环境的时候, 也是调用 resume 的线程.
             协程的执行, 是不和线程依赖的. 它有着自己独立的执行环境的记录.
             但是它一定是切换回调度它的线程环境上.
             线程 -> 协程 -> 线程. 这个逻辑单元, 是不可能打破的.
             但是 线程 -> 协程, 这个调度, 线程环境并不绑定.
             */
            self.complete(with: coroutine.resume())
        }
    }
    
    /*
     self.complete(with: coroutine.start())
     self.complete(with: coroutine.resume())
     */
    private func complete(with state: CompletionState) {
        print("Complete With \(state), \(Thread.current)")
        switch state {
        case .finished:
            started -= 1
            let dispatcher = queueCurrentCoroutine.dispatcher
            queueCurrentCoroutine = nil
            performNext(for: dispatcher)
        case .suspended:
            performNext(for: queueCurrentCoroutine.dispatcher)
        case .restarting:
            // 能够到这里, 是因为 coroutine 的 scheduler 刚刚修改了.
            // 重新使用新的 scheduler 来完成重新进行开启的动作.
            queueCurrentCoroutine.scheduler.scheduleTask {
                // 在 resume 的时候, scheduleTask 进行了调度.
                self.complete(with: self.queueCurrentCoroutine.resume())
            }
        }
    }
    
    private func performNext(for dispatcher: SharedCoroutineDispatcher) {
        let isFinished = atomic.update { _, count in
            count > 0 ? (.running, count - 1) : (.isFree, 0)
        }.new.0 == .isFree
        
        // 判断一下, 当前 Queue 的剩余任务量. 进行任务的调度处理. 
        isFinished ? dispatcher.pushFreeQueue(self) : resumeOnQueue(prepared.blockingPop())
    }
    
    deinit {
        prepared.free()
    }
    
}

fileprivate extension Int32 {
    
    static let running: Int32 = 0
    static let isFree: Int32 = 1
    
}
