internal final class SharedCoroutineQueue {
    
    private struct Task {
        let scheduler: CoroutineScheduler, task: () -> Void
    }
    
    internal enum CompletionState {
        case finished, suspended, restarting
    }
    
    internal let context: CoroutineContext
    // 在一个 SharedCoroutineQueue 中, 只会有一个协程在运转. 
    private var coroutine: SharedCoroutine!
    
    internal var inQueue = false
    private(set) var started = 0
    private var atomic = AtomicTuple()
    private var prepared = FifoQueue<SharedCoroutine>()
    
    internal init(stackSize size: Int) {
        context = CoroutineContext(stackSize: size)
    }
    
    internal func occupy() -> Bool {
        atomic.update(keyPath: \.0, with: .running) == .isFree
    }
    
    // MARK: - Actions
    
    internal func start(dispatcher: SharedCoroutineDispatcher, 
                        scheduler: CoroutineScheduler,
                        task: @escaping () -> Void) {
        coroutine?.saveStack()
        coroutine = SharedCoroutine(dispatcher: dispatcher, queue: self, scheduler: scheduler)
        started += 1
        // 在这里, 才会给协程环境, 添加任务. 
        context.block = task
        reschedule(with: coroutine.start())
    }
    
    internal func resume(coroutine: SharedCoroutine) {
        let (state, _) = atomic.update { state, count in
            if state == .isFree {
                return (.running, count)
            } else {
                return (.running, count + 1)
            }
        }.old
        state == .isFree ? resumeOnQueue(coroutine) : prepared.push(coroutine)
    }
    
    private func resumeOnQueue(_ coroutine: SharedCoroutine) {
        if self.coroutine !== coroutine {
            self.coroutine?.saveStack()
            coroutine.restoreStack()
            self.coroutine = coroutine
        }
        // Resume 的时候, 应该在哪个线程开启任务.
        coroutine.scheduler.scheduleTask {
            self.reschedule(with: coroutine.resume())
        }
    }
    
    private func reschedule(with state: CompletionState) {
        switch state {
        case .finished:
            started -= 1
            let dispatcher = coroutine.dispatcher
            coroutine = nil
            performNext(for: dispatcher)
        case .suspended:
            performNext(for: coroutine.dispatcher)
        case .restarting:
            // restart 的时候, 应该在哪个线程开启任务.
            coroutine.scheduler.scheduleTask {
                self.reschedule(with: self.coroutine.resume())
            }
        }
    }
    
    private func performNext(for dispatcher: SharedCoroutineDispatcher) {
        let isFinished = atomic.update { _, count in
            count > 0 ? (.running, count - 1) : (.isFree, 0)
        }.new.0 == .isFree
        isFinished ? dispatcher.push(self) : resumeOnQueue(prepared.blockingPop())
    }
    
    deinit {
        prepared.free()
    }
    
}

fileprivate extension Int32 {
    
    static let running: Int32 = 0
    static let isFree: Int32 = 1
    
}
