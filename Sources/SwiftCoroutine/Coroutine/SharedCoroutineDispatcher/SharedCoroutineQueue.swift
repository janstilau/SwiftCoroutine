
private var idGenerator: Int = 0

internal final class SharedCoroutineQueue: CustomStringConvertible {
    
    private struct Task {
        let scheduler: CoroutineScheduler, task: () -> Void
    }
    
    internal enum CompletionState {
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
    
    internal func start(
        dispatcher: SharedCoroutineDispatcher,
        scheduler: CoroutineScheduler,
        task: @escaping () -> Void
    ) {
        queueCurrentCoroutine?.saveStack()
        queueCurrentCoroutine = SharedCoroutine(dispatcher: dispatcher, queue: self, scheduler: scheduler)
        started += 1
        context.startTask = task
        self.complete(with: queueCurrentCoroutine.start())
    }
    
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
            // 在 resume 的时候, scheduleTask 进行了调度.
            self.complete(with: coroutine.resume())
        }
    }
    
    /*
     self.complete(with: coroutine.start())
     self.complete(with: coroutine.resume())
     
     complete(with 后面跟着的是 coroutine 重新被调用的代码.
     state 表达的, 就是当前 coroutine 的状态值.
     */
    private func complete(with state: CompletionState) {
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
