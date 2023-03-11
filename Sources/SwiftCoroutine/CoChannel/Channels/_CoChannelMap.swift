internal final class _CoChannelMap<Input, Output>: CoChannel<Output>.Receiver {
    
    private let receiver: CoChannel<Input>.Receiver
    private let transform: (Input) -> Output
    
    // 一个中间的数据盒子.
    // 所有的对于 Receiver 的实现, 都是交给了原本的 Receiver 对象. 自己仅仅是在数据传递的时候, 主动触发了 Transform 的逻辑 .
    internal init(receiver: CoChannel<Input>.Receiver, transform: @escaping (Input) -> Output) {
        self.receiver = receiver
        self.transform = transform
    }
    
    internal override var bufferType: CoChannel<Output>.BufferType {
        switch receiver.bufferType {
        case .buffered(let capacity):
            return .buffered(capacity: capacity)
        case .conflated:
            return .conflated
        case .none:
            return .none
        case .unlimited:
            return .unlimited
        }
    }

    // MARK: - receive
    
    internal override func awaitReceive() throws -> Output {
        try transform(receiver.awaitReceive())
    }
    
    internal override func poll() -> Output? {
        receiver.poll().map(transform)
    }
    
    internal override func whenReceive(_ callback: @escaping (Result<Output, CoChannelError>) -> Void) {
        receiver.whenReceive { callback($0.map(self.transform)) }
    }
    
    internal override var count: Int {
        receiver.count
    }
    
    internal override var isEmpty: Bool {
        receiver.isEmpty
    }
    
    // MARK: - close
    
    internal override var isClosed: Bool {
        receiver.isClosed
    }
    
    // MARK: - cancel
    
    internal override func cancel() {
        receiver.cancel()
    }
    
    internal override var isCanceled: Bool {
        receiver.isCanceled
    }
    
    // MARK: - complete
    
    internal override func whenFinished(_ callback: @escaping (CoChannelError?) -> Void) {
        receiver.whenFinished(callback)
    }
    
}
