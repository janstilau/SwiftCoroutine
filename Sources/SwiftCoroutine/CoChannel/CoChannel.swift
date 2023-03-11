/// Channel is a non-blocking primitive for communication between a sender and a receiver.
/// Conceptually, a channel is similar to a queue that allows to suspend a coroutine on receive if it is empty or on send if it is full.
///
/// - Important: Always `close()` or `cancel()` a channel when you are done to resume all suspended coroutines by the channel.
///
/// ```
/// let channel = CoChannel<Int>(capacity: 1)
///
/// DispatchQueue.global().startCoroutine {
///    for i in 0..<100 {
///    // 在这里生产数据, 然后发出, 如果在发出的过程中, 发现 Full 了, 就会停止当前的协程.
///        try channel.awaitSend(i)
///    }
///    channel.close()
/// }
///
/// DispatchQueue.global().startCoroutine {
/// // 这里其实是 awaitReceive 的情况. 如果发现当前没有数据了, 就进行 await.
///     for i in channel.makeIterator() {
///         print("Receive", i)
///     }
///     print("Done")
/// }
///
// 在两个协程里面, 进行wait 和 send.
public final class CoChannel<Element> {
    
    /// `CoChannel` buffer type.
    public enum BufferType: Equatable {
        /// This channel does not have any buffer.
        ///
        /// An element is transferred from the sender to the receiver only when send and receive invocations meet in time,
        /// so `awaitSend(_:)` suspends until invokes receive, and `awaitReceive()` suspends until invokes send.
        // 不会有缓存, 一个生成了, 一个消费.
        case none
        /// This channel have a buffer with the specified capacity.
        ///
        /// `awaitSend(_:)` suspends only when the buffer is full,
        /// and `awaitReceive()` suspends only when the buffer is empty.
        // 会有缓存数据.
        case buffered(capacity: Int)
        /// This channel has a buffer with unlimited capacity.
        ///
        /// `awaitSend(_:)` to this channel never suspends, and offer always returns true.
        /// `awaitReceive()` suspends only when the buffer is empty.
        // 会有缓存数据, 并且无限缓存. 就和 NSMutableArray 一样, 可以无限的进行扩容.
        case unlimited
        // 会替换??? 只用最后一个, 所以其实没有 await send.
        // 生产者永远不会陷入停滞的状态.
        /// This channel buffers at most one element and offer invocations,
        /// so that the receiver always gets the last element sent.
        ///
        /// Only the last sent element is received, while previously sent elements are lost.
        /// `awaitSend(_:)` to this channel never suspends, and offer always returns true.
        /// `awaitReceive()` suspends only when the buffer is empty.
        // conflate 合并.
        case conflated
    }
        
    /*
     这才是一个比较好的设计. 使用 Type 来进行内部抽象对象的构建工作, 而不是在内部, 使用 type 进行大量的 swiftch 判断.
     */
    @usableFromInline internal let channel: _Channel<Element>
    
    /// Initializes a channel.
    /// - Parameter type: The type of channel buffer.
    public init(bufferType type: BufferType = .unlimited) {
        switch type {
        case .conflated:
            channel = _ConflatedChannel()
        case .buffered(let capacity):
            channel = _BufferedChannel(capacity: capacity)
        case .unlimited:
            channel = _BufferedChannel(capacity: .max)
        case .none:
            // None 就是没有缓存而已.
            // 所以实际上, 大部分还是使用了 _BufferedChannel 这个内部的数据类型.
            // 可以看到, 在通用的第三方库里面, 使用 _ 做前缀也是一个很常用的设计. 
            channel = _BufferedChannel(capacity: 0)
        }
    }
    
    /// Initializes a channel with `BufferType.buffered(capacity:)` .
    /// - Parameter capacity: The maximum number of elements that can be stored in a channel.
    // 直接指定了最常用的 _BufferedChannel
    public init(capacity: Int) {
        channel = _BufferedChannel(capacity: capacity)
    }
    
}

extension CoChannel {
    /*
     这是一个优秀的设计. 铁定是操作同一个对象, 不然怎么实现生产者和消费者之间的交互.
     但是不能直接暴露这个对象给外界. 所以, 要使用一个代理对象将真正的 channel 藏起来.
     暴露出去的代理对象, 就是 Sender 对象.
     */
    /// A `CoChannel` wrapper that provides send-only functionality.
    @inlinable public var sender: Sender {
        Sender(channel: channel)
    }
    
    /// Sends the element to this channel, suspending the coroutine while the buffer of this channel is full.
    /// Must be called inside a coroutine.
    /// - Parameter element: Value that will be sent to the channel.
    /// - Throws: CoChannelError when canceled or closed.
    @inlinable public func awaitSend(_ element: Element) throws {
        try channel.awaitSend(element)
    }
    
    
    /// Adds the future's value to this channel when it will be available.
    /// - Parameter future: `CoFuture`'s value that will be sent to the channel.
    @inlinable public func sendFuture(_ future: CoFuture<Element>) {
        channel.sendFuture(future)
    }
    
    // 这个是一个类似于 try 的设计
    /// Immediately adds the value to this channel, if this doesn’t violate its capacity restrictions, and returns true.
    /// Otherwise, just returns false.
    /// - Parameter element: Value that might be sent to the channel.
    /// - Returns:`true` if sent successfully or `false` if channel buffer is full or channel is closed or canceled.
    @discardableResult @inlinable public func offer(_ element: Element) -> Bool {
        channel.offer(element)
    }
    
}

extension CoChannel {
    /// A `CoChannel` wrapper that provides receive-only functionality.
    @inlinable public var receiver: Receiver { channel }
    
    /// Retrieves and removes an element from this channel if it’s not empty, or suspends a coroutine while the channel is empty.
    /// - Throws: CoChannelError when canceled or closed.
    /// - Returns: Removed value from the channel.
    @inlinable public func awaitReceive() throws -> Element {
        try channel.awaitReceive()
    }
    
    /// Creates `CoFuture` with retrieved value from this channel.
    /// - Returns: `CoFuture` with a future value from the channel.
    @inlinable public func receiveFuture() -> CoFuture<Element> {
        channel.receiveFuture()
    }
    
    /// Retrieves and removes an element from this channel.
    /// - Returns: Element from this channel if its not empty, or returns nill if the channel is empty or is closed or canceled.
    // 这是一个类似于 poll 的设计.
    @inlinable public func poll() -> Element? {
        channel.poll()
    }
    
    /// Adds an observer callback to receive an element from this channel.
    /// - Parameter callback: The callback that is called when a value is received.
    @inlinable public func whenReceive(_ callback: @escaping (Result<Element, CoChannelError>) -> Void) {
        channel.whenReceive(callback)
    }
    
    /// Returns a number of elements in this channel.
    @inlinable public var count: Int {
        channel.count
    }
    
    /// Returns `true` if the channel is empty (contains no elements), which means no elements to receive.
    @inlinable public var isEmpty: Bool {
        channel.isEmpty
    }
}

extension CoChannel {
    
    /// The type of channel buffer.
    @inlinable public var bufferType: BufferType {
        channel.bufferType
    }
    
    /// Returns tuple of `Receiver` and `Sender`.
    @inlinable public var pair: (receiver: Receiver, sender: Sender) {
        (channel, sender)
    }
    
   
    
    // MARK: - map
    
    /// Returns new `Receiver` that provides transformed values from this `CoChannel`.
    /// - Parameter transform: A mapping closure.
    /// - returns: A `Receiver` with transformed values.
    @inlinable public func map<T>(_ transform: @escaping (Element) -> T) -> CoChannel<T>.Receiver {
        // 就和 lazy, 或者 conbine 一样, 这种异步的 API, 只是将变形的逻辑, 存放到了一个盒子里面.
        // 然后在这个盒子里面, 真正的数据, 产生后, 会先经过盒子. 
        channel.map(transform)
    }
    
    // MARK: - close
    
    /// Closes this channel. No more send should be performed on the channel.
    /// - Returns: `true` if closed successfully or `false` if channel is already closed or canceled.
    @discardableResult @inlinable public func close() -> Bool {
        channel.close()
    }
    
    /// Returns `true` if the channel is closed.
    @inlinable public var isClosed: Bool {
        channel.isClosed
    }
    
    // MARK: - cancel
    
    /// Closes the channel and removes all buffered sent elements from it.
    @inlinable public func cancel() {
        channel.cancel()
    }
    
    /// Returns `true` if the channel is canceled.
    @inlinable public var isCanceled: Bool {
        channel.isCanceled
    }
    
    /// Adds an observer callback that is called when the `CoChannel` is canceled.
    /// - Parameter callback: The callback that is called when the `CoChannel` is canceled.
    @inlinable public func whenCanceled(_ callback: @escaping () -> Void) {
        channel.whenCanceled(callback)
    }
    
    // MARK: - complete
    
    /// Adds an observer callback that is called when the `CoChannel` is completed (closed, canceled or deinited).
    /// - Parameter callback: The callback that is called when the `CoChannel` is completed.
    @inlinable public func whenComplete(_ callback: @escaping () -> Void) {
        channel.whenComplete(callback)
    }
    
}

extension CoChannel {
    
    // MARK: - sequence
    
    /// Make an iterator which successively retrieves and removes values from the channel.
    ///
    /// If `next()` was called inside a coroutine and there are no more elements in the channel,
    /// then the coroutine will be suspended until a new element will be added to the channel or it will be closed or canceled.
    /// - Returns: Iterator for the channel elements.
    @inlinable public func makeIterator() -> AnyIterator<Element> {
        channel.makeIterator()
    }
    
}
