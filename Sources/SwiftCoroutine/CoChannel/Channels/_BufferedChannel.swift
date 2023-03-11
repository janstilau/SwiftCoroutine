extension Int32 {
    var isClosed: Bool {
        return self == 1
    }
}

internal final class _BufferedChannel<T>: _Channel<T> {
    
    private typealias ReceiveCallback = (Result<T, CoChannelError>) -> Void
    private struct SendBlock { let element: T, resumeBlock: ((CoChannelError?) -> Void)? }
    
    private let capacity: Int
    private var receiveCallbacks = FifoQueue<ReceiveCallback>()
    private var sendBlocks = FifoQueue<SendBlock>()
    private var leftCachedCountAndState = AtomicTuple()
    
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
    
    /*
        Send 的最后逻辑, 都有着 Count 的判断.
     如果是 < 0, 那么就是有着 Receiver 在等在, 直接调用 receiveCallbacks, 其中其实存储了唤醒等待协程的能力.
     而如果没有, 则就是将自己的产出, 存储到 sendBlocks 中去.
     */
    internal override func awaitSend(_ element: T) throws {
        switch leftCachedCountAndState.updateThenReturnOld ({ count, state in
            if state.isClosed { return (count, state) }
            return (count + 1, 0)
        }).old {
        case (_, 1):
            throw CoChannelError.closed
        case (_, 2):
            throw CoChannelError.canceled
        case (let count, _) where count < 0:
            // < 0 代表着当前有着消费者正在等待消费, 直接就进行
            receiveCallbacks.blockingPop()(.success(element))
        case (let count, _) where count < capacity:
            // 具有缓存功能, 就直接将数据存进去. 等待着 receiver 来进行消费.
            sendBlocks.push(.init(element: element, resumeBlock: nil))
        default:
            // 最重要的能力了, 停滞当前的协程.
            // 直到 Receiver 来消费了, 才恢复进行.
            //
            try CoroutineStruct.await {
                // let $0: (CoChannelError?) -> Void
                // 这个 $0, 其实是 ShareCoroutine 里面定义的, 里面的功能就是恢复原有的协程.
                sendBlocks.push(.init(element: element, resumeBlock: $0))
            }.map { throw $0 }
        }
    }
    
    /// Adds the future's value to this channel when it will be available.
    internal override func sendFuture(_ future: CoFuture<T>) {
        future.whenSuccess { [weak self] in
            guard let self = self else { return }
            let (count, state) = self.leftCachedCountAndState.updateThenReturnOld { count, state in
                if state.isClosed { return (count, state) }
                return (count + 1, 0)
            }.old
            guard state == 0 else { return }
            count < 0
            ? self.receiveCallbacks.blockingPop()(.success($0))
            : self.sendBlocks.push(.init(element: $0, resumeBlock: nil))
        }
    }
    
    internal override func offer(_ element: T) -> Bool {
        let (count, state) = leftCachedCountAndState.updateThenReturnOld { count, state in
            if state.isClosed || count >= capacity { return (count, state) }
            return (count + 1, 0)
        }.old
        if state.isClosed { return false }
        
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
        switch leftCachedCountAndState.updateThenReturnOld({ count, state in
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
        case (let count, let state) where count > 0:
            defer { if count == 1, state == 1 { finish() } }
            return getValue()
        case (_, 0):
            // 没了, 就将 Completion 存储到 receiveCallbacks 中, 也就是$0.
            // 其中 $0 会有对于 Receiver 协程的唤醒操作.
            return try CoroutineStruct.await { receiveCallbacks.push($0) }.get()
        case (_, 1):
            throw CoChannelError.closed
        default:
            throw CoChannelError.canceled
        }
    }
    
    // 如果有值, 就进行取值.
    // 没有值, 就进行 wait. 
    internal override func poll() -> T? {
        let (count, state) = leftCachedCountAndState.updateThenReturnOld { count, state in
            (Swift.max(0, count - 1), state)
        }.old
        guard count > 0 else { return nil }
        defer { if count == 1, state == 1 { finish() } }
        return getValue()
    }
    
    internal override func whenReceive(_ callback: @escaping (Result<T, CoChannelError>) -> Void) {
        switch leftCachedCountAndState.updateThenReturnOld({ count, state in
            if state == 0 { return (count - 1, 0) }
            return (Swift.max(0, count - 1), state)
        }).old {
        case (let count, let state) where count > 0:
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
        Int(max(0, leftCachedCountAndState.value.0))
    }
    
    internal override var isEmpty: Bool {
        leftCachedCountAndState.value.0 <= 0
    }
    
    private func getValue() -> T {
        let dataAndResumeFunc = sendBlocks.blockingPop()
        dataAndResumeFunc.resumeBlock?(nil) // Receiver 唤醒了 Sender.
        return dataAndResumeFunc.element
    }
    
    // MARK: - close
    
    internal override func close() -> Bool {
        let (count, state) = leftCachedCountAndState.updateThenReturnOld { count, state in
            state == 0 ? (Swift.max(0, count), 1) : (count, state)
        }.old
        guard state == 0 else { return false }
        if count < 0 {
            for _ in 0..<count.magnitude {
                receiveCallbacks.blockingPop()(.failure(.closed))
            }
        } else if count > 0 {
            sendBlocks.forEach { $0.resumeBlock?(.closed) }
        } else {
            finish()
        }
        return true
    }
    
    internal override var isClosed: Bool {
        leftCachedCountAndState.value.1 == 1
    }
    
    // MARK: - cancel
    
    internal override func cancel() {
        let count = leftCachedCountAndState.updateThenReturnOld { _ in (0, 2) }.old.0
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
        leftCachedCountAndState.value.1 == 2
    }
    
    deinit {
        while let block = receiveCallbacks.pop() {
            block(.failure(.canceled))
        }
        receiveCallbacks.free()
        sendBlocks.free()
    }
    
}
