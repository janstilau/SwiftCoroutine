
@usableFromInline internal final class SharedCoroutineDispatcher {
    
    @usableFromInline internal
    static let `default` = SharedCoroutineDispatcher(capacity: .processorsNumber * 2,
                                                     stackSize: .recommended)
    
    private let stackSize: Int // 这个值, 唯一的作用, 就是在创建 SharedCoroutineQueue 的时候.
    private let capacity: Int
    private var queues = FifoQueue<SharedCoroutineQueue>()
    private var queuesCount = 0
    
    internal init(capacity: Int, stackSize: Coroutine.StackSize) {
        self.stackSize = stackSize.size
        self.capacity = capacity
    }
    
    @usableFromInline
    internal func executeCoroutionStart(on scheduler: CoroutineScheduler, // 调度器.
                                        coroutionStartTask: @escaping () -> Void // 真正的协程任务.
    ) {
        scheduler.scheduleTask {
            self.getFreeQueue().start(dispatcher: self,
                                      scheduler: scheduler,
                                      task: coroutionStartTask)
        }
    }
    
    private func getFreeQueue() -> SharedCoroutineQueue {
        while let queue = queues.pop() {
            // QueueCount 没有直接维护在 quques 里面, 而是在外面使用一个成员变量进行的维护.
            atomicAdd(&queuesCount, value: -1)
            queue.isInFreeQueue = false
            if queue.occupy() { return queue }
        }
        // 真正的, 进行 Queue 生成的地方.
        // 当, queue 中没有 Coroutine 等待执行的时候, 会将 queue 添加到 dispatcher 的 freeQueues 中. 
        return SharedCoroutineQueue(stackSize: stackSize)
    }
    
    // SharedCoroutineQueue 不会在调用方进行生成.  SharedCoroutineQueue 只会在上面的 getFreeQueue 中进行生成.
    internal func pushFreeQueue(_ queue: SharedCoroutineQueue) {
        if queue.started != 0 {
            if queue.isInFreeQueue { return }
            queue.isInFreeQueue = true
            queues.push(queue)
            // QueueCount 没有直接维护在 quques 里面, 而是在外面使用一个成员变量进行的维护.
            atomicAdd(&queuesCount, value: 1)
        } else if queuesCount < capacity {
            queues.insertAtStart(queue)
            // QueueCount 没有直接维护在 quques 里面, 而是在外面使用一个成员变量进行的维护.
            atomicAdd(&queuesCount, value: 1)
        }
    }
    
    deinit {
        queues.free()
    }
    
}
