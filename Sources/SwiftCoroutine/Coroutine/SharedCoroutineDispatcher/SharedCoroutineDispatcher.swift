
/*
 该类最主要的责任, 就是进行 Queue 的管理. 
 */
@usableFromInline internal final class SharedCoroutineDispatcher {
    
    @usableFromInline internal
    static let `default` = SharedCoroutineDispatcher(capacity: .processorsNumber * 2,
                                                     stackSize: .recommended)
    
    private let stackSize: Int
    private let queueCapacity: Int
    private var queueWithRoutineQueue = FifoQueue<SharedCoroutineQueue>()
    private var queuesCount = 0
    
    internal init(capacity: Int, stackSize: CoroutineStruct.StackSize) {
        self.stackSize = stackSize.size
        self.queueCapacity = capacity
    }
    
    @usableFromInline
    internal func execute(on scheduler: CoroutineScheduler,
                          task: @escaping () -> Void) {
        // 在启动任务的时候, CoroutineScheduler 发挥了作用. 
        scheduler.scheduleTask {
            self.getFreeQueue().start(dispatcher: self, scheduler: scheduler, task: task)
        }
    }
    
    private func getFreeQueue() -> SharedCoroutineQueue {
        while let queue = queueWithRoutineQueue.pop() {
            atomicAdd(&queuesCount, value: -1)
            queue.inQueue = false
            if queue.occupy() { return queue }
        }
        return SharedCoroutineQueue(stackSize: stackSize)
    }
    
    internal func push(_ queue: SharedCoroutineQueue) {
        if queue.started != 0 {
            if queue.inQueue { return }
            queue.inQueue = true
            queueWithRoutineQueue.push(queue)
            atomicAdd(&queuesCount, value: 1)
        } else if queuesCount < queueCapacity {
            queueWithRoutineQueue.insertAtStart(queue)
            atomicAdd(&queuesCount, value: 1)
        }
    }
    
    deinit {
        queueWithRoutineQueue.free()
    }
    
}
