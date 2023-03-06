

internal final class SharedCoroutineQueue {
    
    internal enum RoutineState {
        case finished, suspended, restarting
    }
    
    internal let context: CoroutineContext
    private var currentCoroutine: SharedCoroutine!
    
    internal var inQueue = false
    private(set) var started = 0
    private var stateAndCount = AtomicTuple()
    // 这个队列里面存放的, 都是可以被调度的协程.
    // 在协程的 resumeIfNeed 中, 才会触发重新调度自己的逻辑.
    // 如果协程状态一直没有 runing, 那么也就不需要被切换, 就像线程不会被切换一样.
    private var waitingForSchedule = FifoQueue<SharedCoroutine>()
    
    internal init(stackSize size: Int) {
        context = CoroutineContext(stackSize: size)
    }
    
    internal func occupy() -> Bool {
        stateAndCount.updateThenReturnOld(key: "state", with: .running) == .isFree
    }
    
    // MARK: - Actions
    
    internal func start(dispatcher: SharedCoroutineDispatcher,
                        scheduler: CoroutineScheduler,
                        task: @escaping () -> Void) {
        currentCoroutine?.saveStack()
        currentCoroutine = SharedCoroutine(dispatcher: dispatcher, queue: self, scheduler: scheduler)
        started += 1
        context.businessBlock = task
        reschedule(with: currentCoroutine.start())
    }
    
    /*
     异步操作的回调, 会触发到这里. 
     */
    internal func resume(coroutine: SharedCoroutine) {
        let (state, _) = stateAndCount.updateThenReturnOld { state, count in
            if state == .isFree {
                return (.running, count)
            } else {
                return (.running, count + 1)
            }
        }.old
        state == .isFree ? resumeOnQueue(coroutine) : waitingForSchedule.push(coroutine)
    }
    
    private func resumeOnQueue(_ coroutine: SharedCoroutine) {
        if self.currentCoroutine !== coroutine {
            self.currentCoroutine?.saveStack()
            coroutine.restoreStack()
            self.currentCoroutine = coroutine
        }
        // 在重新进行协程相关逻辑开启的时候, 主动进行一次调度.
        // 因为触发协程可以调度的线程, 可能是子线程. 主动进行一次调度, 才能保证协程相关的代码在对应的环境下.
        coroutine.scheduler.scheduleTask {
            self.reschedule(with: coroutine.resume())
        }
    }
    
    private func reschedule(with state: RoutineState) {
        switch state {
        case .finished:
            started -= 1
            let dispatcher = currentCoroutine.dispatcher
            // 只有 finished 才会修改 currentCoroutine 的值为 nil.
            currentCoroutine = nil
            performNext(for: dispatcher)
        case .suspended:
            performNext(for: currentCoroutine.dispatcher)
        case .restarting:
            currentCoroutine.scheduler.scheduleTask {
                self.reschedule(with: self.currentCoroutine.resume())
            }
        }
    }
    
    // 这个 dispatcher, 只是为了让 queue 回收. 
    private func performNext(for dispatcher: SharedCoroutineDispatcher) {
        let isFinished = stateAndCount.updateThenReturnOld { _, count in
            count > 0 ? (.running, count - 1) : (.isFree, 0)
        }.new.0 == .isFree
        isFinished ? dispatcher.push(self) : resumeOnQueue(waitingForSchedule.blockingPop())
    }
    
    deinit {
        waitingForSchedule.free()
    }
    
}

fileprivate extension Int32 {
    static let running: Int32 = 0
    static let isFree: Int32 = 1
    
}
