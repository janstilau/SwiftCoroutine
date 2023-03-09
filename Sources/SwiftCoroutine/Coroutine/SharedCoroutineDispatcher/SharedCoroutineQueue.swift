

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
        context.coroutineStartFunc = task
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
        
        /*
         coroutine 中 start, suspend, resume 等操作, 都是没有锁的, 因为按照协程的设计, 是不会出现一个协程对象, 会同时被多个线程访问的.
         协程 wait 的时候, 记录原本的协程调用堆栈, 寄存器, PC 计数器的信息, 然后将指令跳转到 returnJumpBuffer 中.
         协程 resume 的时候, 是修改自身的状态, 然后等待 queue 来重新 resume 自己.
         在这个重新 resume 的过程中, scheduler.scheduleTask 使得协程恢复的时候, 线程可能发生变化.
         但是没有问题, 就是将协程运行环境, 在新的线程恢复就可以了,  因为协程完整复制了自己的运行环境.
         这也就是为什么 resume 的前后, 会有线程之间的变换, 但是调用栈中的数据是不会在多线程中访问的, 堆中的对象还是多线程之间同时共享.
         
         协程实际上, 解决的是代码线性执行的问题, 并没有做运行线程的确定. 
         */
        
        // 这里的触发线程, 就是异步操作回调 completion 的触发线程. 
        print("即将发生协程的上下文恢复 \(coroutine), 当前线程是 \(Thread.current), 会使用 scheduler 进行调度")
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
