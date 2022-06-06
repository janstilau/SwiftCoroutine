
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
    private var coroutine: SharedCoroutine! // 当前正在运行的协程对象.
    
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
        coroutine?.saveStack()
        coroutine = SharedCoroutine(dispatcher: dispatcher, queue: self, scheduler: scheduler)
        started += 1
        context.startTask = task
        complete(with: coroutine.start())
    }
    
    // 真正的, 进行协程恢复的地方.
    internal func resume(coroutine: SharedCoroutine) {
        let (state, _) = atomic.update { state, count in
            if state == .isFree {
                return (.running, count)
            } else {
                return (.running, count + 1)
            }
        }.old
        
        // 如果, 当前正在进行进行协程处理. 不会立马触发传入的新的协程对象.
        state == .isFree ? resumeOnQueue(coroutine) : prepared.push(coroutine)
    }
    
    private func resumeOnQueue(_ coroutine: SharedCoroutine) {
        if self.coroutine !== coroutine {
            // 原有协程的状态存储.
            self.coroutine?.saveStack()
            // 新来的协程的恢复.
            coroutine.restoreStack()
            self.coroutine = coroutine
        }
        coroutine.scheduler.scheduleTask {
            // 在 resume 的时候, scheduleTask 进行了调度.
            self.complete(with: coroutine.resume())
        }
    }
    
    // 如果, CompletionState 是 Finished 了, 就是这个协程的任务已经做完了, 就可以进行重用了.
    private func complete(with state: CompletionState) {
        switch state {
        case .finished:
            started -= 1
            let dispatcher = coroutine.dispatcher
            coroutine = nil
            performNext(for: dispatcher)
        case .suspended:
            performNext(for: coroutine.dispatcher)
        case .restarting:
            // 能够到这里, 是因为 coroutine 的 scheduler 刚刚修改了.
            // 重新使用新的 scheduler 来完成重新进行开启的动作. 
            coroutine.scheduler.scheduleTask {
                // 在 resume 的时候, scheduleTask 进行了调度.
                self.complete(with: self.coroutine.resume())
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
