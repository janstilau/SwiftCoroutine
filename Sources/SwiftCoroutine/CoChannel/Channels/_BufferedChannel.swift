internal final class _BufferedChannel<T>: _Channel<T> {
    
    private typealias ReceiveCallback = (Result<T, CoChannelError>) -> Void
    private struct SendBlock {
        let element: T
        let resumeBlock: ((CoChannelError?) -> Void)?
    }
    
    private let capacity: Int
    private var receiveCallbacks = FifoQueue<ReceiveCallback>()
    private var sendBlocks = FifoQueue<SendBlock>()
    private var atomic = AtomicTuple()
    
    internal init(capacity: Int) {
        self.capacity = max(0, capacity)
    }
    
    internal override var bufferType: CoChannel<T>.BufferType {
        switch capacity {
        case .max: return .unlimited
        case 0: return .none
        case let capacity: return .buffered(capacity: capacity)
        }
    }
    
    // MARK: - send
    // 向 channel 里面, 填充数据.
    internal override func awaitSend(_ element: T) throws {
        switch atomic.update ({ count, state in
            if state != 0 { return (count, state) }
            return (count + 1, 0)
        }).old {
        case (_, 1):
            throw CoChannelError.closed
        case (_, 2):
            throw CoChannelError.canceled
            /*
             count 代表着队列先有存货. 如果 < 0, 就是有等的.
             如果大于零, 就是没等的, 有富裕.
             */
        case (let count, _) where count < 0:
            // 触发停止的协程, 有数据了.
            receiveCallbacks.blockingPop()(.success(element))
        case (let count, _) where count < capacity:
            // 如果还没有达到 capacity, 那么就是存起来,
            sendBlocks.push(.init(element: element, resumeBlock: nil))
        default:
            // 已经冒了, 就让现在的协程停止. 当有读取的时候, 才会重新开启.
            let result = try CoroutineSpace.await { routineResume in
                sendBlocks.push(.init(element: element, resumeBlock: routineResume))
            }
            try result.map { throw $0 }
        }
    }
    
    internal override func sendFuture(_ future: CoFuture<T>) {
        future.whenSuccess { [weak self] in
            guard let self = self else { return }
            let (count, state) = self.atomic.update { count, state in
                if state != 0 { return (count, state) }
                return (count + 1, 0)
            }.old
            guard state == 0 else { return }
            count < 0
            ? self.receiveCallbacks.blockingPop()(.success($0))
            : self.sendBlocks.push(.init(element: $0, resumeBlock: nil))
        }
    }
    
    internal override func offer(_ element: T) -> Bool {
        let (count, state) = atomic.update { count, state in
            if state != 0 || count >= capacity { return (count, state) }
            return (count + 1, 0)
        }.old
        if state != 0 { return false }
        if count < 0 {
            receiveCallbacks.blockingPop()(.success(element))
            return true
        } else if count < capacity {
            sendBlocks.push(.init(element: element, resumeBlock: nil))
            return true
        }
        return false
    }
    
    // MARK: - receive
    
    internal override func awaitReceive() throws -> T {
        switch atomic.update({ count, state in
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
        case (let count, let state) where count > 0:
            defer { if count == 1, state == 1 { finish() } }
            return getValue()
        case (_, 0):
            return try CoroutineSpace.await { routineResume in
                receiveCallbacks.push(routineResume)
            }.get()
        case (_, 1):
            throw CoChannelError.closed
        default:
            throw CoChannelError.canceled
        }
    }
    
    // 同步方法, 当前没有不停止. 
    internal override func poll() -> T? {
        let (count, state) = atomic.update { count, state in
            (Swift.max(0, count - 1), state)
        }.old
        guard count > 0 else { return nil }
        
        defer { if count == 1, state == 1 { finish() } }
        return getValue()
    }
    
    // 
    internal override func whenReceive(_ callback: @escaping (Result<T, CoChannelError>) -> Void) {
        switch atomic.update({ count, state in
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
        case (let count, let state) where count > 0:
            // 每次消耗值之后, 才会触发 finish.
            callback(.success(getValue()))
            if count == 1, state == 1 { finish() }
        case (_, 0):
            receiveCallbacks.push(callback)
        case (_, 1):
            callback(.failure(.closed))
        default:
            callback(.failure(.canceled))
        }
    }
    
    internal override var count: Int {
        Int(max(0, atomic.value.0))
    }
    
    internal override var isEmpty: Bool {
        atomic.value.0 <= 0
    }
    
    private func getValue() -> T {
        let block = sendBlocks.blockingPop()
        block.resumeBlock?(nil)
        return block.element
    }
    
    // MARK: - close
    
    internal override func close() -> Bool {
        let (count, state) = atomic.update { count, state in
            state == 0 ? (Swift.max(0, count), 1) : (count, state)
        }.old
        guard state == 0 else { return false }
        if count < 0 {
            for _ in 0..<count.magnitude {
                receiveCallbacks.blockingPop()(.failure(.closed))
            }
        } else if count > 0 {
            // close 了, 要向还在等待的协程, 发送对应的 error.
            sendBlocks.forEach { $0.resumeBlock?(.closed) }
        } else {
            finish()
        }
        return true
    }
    
    internal override var isClosed: Bool {
        atomic.value.1 == 1
    }
    
    // MARK: - cancel
    
    internal override func cancel() {
        let count = atomic.update { _ in (0, 2) }.old.0
        if count < 0 {
            for _ in 0..<count.magnitude {
                receiveCallbacks.blockingPop()(.failure(.canceled))
            }
        } else if count > 0 {
            for _ in 0..<count {
                sendBlocks.blockingPop().resumeBlock?(.canceled)
            }
        }
        finish()
    }
    
    internal override var isCanceled: Bool {
        atomic.value.1 == 2
    }
    
    deinit {
        while let block = receiveCallbacks.pop() {
            block(.failure(.canceled))
        }
        receiveCallbacks.free()
        sendBlocks.free()
    }
    
}
