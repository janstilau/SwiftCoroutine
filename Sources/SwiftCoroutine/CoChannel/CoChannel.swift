// 这可以认为是 AsyncSequence 的实现.

/// Channel is a non-blocking primitive for communication between a sender and a receiver.
// 这里说的很清楚, 会有一个缓存区的概念.
// 作为 Sender, 当缓存区满的时候 await.
// 作为 Receiver, 当缓存区空的时候, await.

/// Conceptually, a channel is similar to a queue that allows to
/// suspend  on receive if it is empty
/// suspend  on send if it is full.
/// - Important: Always `close()` or `cancel()` a channel when you are done to resume all suspended coroutines by the channel.
///

/// ```
/// let channel = CoChannel<Int>(capacity: 1)
///
/// DispatchQueue.global().startCoroutine {
///    for i in 0..<100 {
///        try channel.awaitSend(i)
///    }
///    channel.close()
/// }

// 后面的在消耗, 但是, 只有前面的进行了添加之后, 后面的才能真正的进行获取.
///
/// DispatchQueue.global().startCoroutine {
///     for i in channel.makeIterator() {
///         print("Receive", i)
///     }
///     print("Done")
/// }
/// ```

public final class CoChannel<Element> {
    
    /// `CoChannel` buffer type.
    public enum BufferType: Equatable {
        /// This channel does not have any buffer.
        /// An element is transferred from the sender to the receiver only when send and receive invocations meet in time,
        /// so `awaitSend(_:)` suspends until invokes receive, and `awaitReceive()` suspends until invokes send.
        // 使用这种方式, 就是没有缓存的概念.
        // 只要生产了, 就
        case none
        /// This channel have a buffer with the specified capacity.
        ///
        /// `awaitSend(_:)` suspends only when the buffer is full,
        /// and `awaitReceive()` suspends only when the buffer is empty.
        case buffered(capacity: Int)
        /// This channel has a buffer with unlimited capacity.
        ///
        /// `awaitSend(_:)` to this channel never suspends, and offer always returns true.
        /// `awaitReceive()` suspends only when the buffer is empty.
        // 可以想象, 这种方式, 会耗费掉多少内存
        case unlimited
        /// This channel buffers at most one element and offer invocations,
        /// so that the receiver always gets the last element sent.
        ///
        /// Only the last sent element is received, while previously sent elements are lost.
        /// `awaitSend(_:)` to this channel never suspends, and offer always returns true.
        /// `awaitReceive()` suspends only when the buffer is empty.
        case conflated
    }
    
    // 一个抽象基类.
    @usableFromInline internal let _innerChannel: _Channel<Element>
    
    /// Initializes a channel.
    /// - Parameter type: The type of channel buffer.
    public init(bufferType type: BufferType = .unlimited) {
        switch type {
        case .conflated:
            _innerChannel = _ConflatedChannel()
        case .buffered(let capacity):
            _innerChannel = _BufferedChannel(capacity: capacity)
        case .unlimited:
            _innerChannel = _BufferedChannel(capacity: .max)
        case .none:
            _innerChannel = _BufferedChannel(capacity: 0)
        }
    }
    
    /// Initializes a channel with `BufferType.buffered(capacity:)` .
    /// - Parameter capacity: The maximum number of elements that can be stored in a channel.
    public init(capacity: Int) {
        _innerChannel = _BufferedChannel(capacity: capacity)
    }
    
}

extension CoChannel {
    
    /// The type of channel buffer.
    @inlinable public var bufferType: BufferType {
        _innerChannel.bufferType
    }
    
    /// Returns tuple of `Receiver` and `Sender`.
    @inlinable public var pair: (receiver: Receiver, sender: Sender) {
        (_innerChannel, sender)
    }
    
    // MARK: - send
    
    /// A `CoChannel` wrapper that provides send-only functionality.
    // 每次都是一个新的对象, 但是操作的是同样的一个 Channel 对象.
    @inlinable public var sender: Sender {
        Sender(channel: _innerChannel)
    }
    
    /// Sends the element to this channel, suspending the coroutine while the buffer of this channel is full.
    /// Must be called inside a coroutine.
    /// - Parameter element: Value that will be sent to the channel.
    /// - Throws: CoChannelError when canceled or closed.
    @inlinable public func awaitSend(_ element: Element) throws {
        try _innerChannel.awaitSend(element)
    }
    
    /// Adds the future's value to this channel when it will be available.
    /// - Parameter future: `CoFuture`'s value that will be sent to the channel.
    @inlinable public func sendFuture(_ future: CoFuture<Element>) {
        _innerChannel.sendFuture(future)
    }
    
    /// Immediately adds the value to this channel, if this doesn’t violate its capacity restrictions, and returns true.
    /// Otherwise, just returns false.
    /// - Parameter element: Value that might be sent to the channel.
    /// - Returns:`true` if sent successfully or `false` if channel buffer is full or channel is closed or canceled.
    @discardableResult @inlinable public func offer(_ element: Element) -> Bool {
        _innerChannel.offer(element)
    }
    
    // MARK: - receive
    
    /// A `CoChannel` wrapper that provides receive-only functionality.
    @inlinable public var receiver: Receiver { _innerChannel }
    
    /// Retrieves and removes an element from this channel if it’s not empty, or suspends a coroutine while the channel is empty.
    /// - Throws: CoChannelError when canceled or closed.
    /// - Returns: Removed value from the channel.
    @inlinable public func awaitReceive() throws -> Element {
        try _innerChannel.awaitReceive()
    }
    
    /// Creates `CoFuture` with retrieved value from this channel.
    /// - Returns: `CoFuture` with a future value from the channel.
    @inlinable public func receiveFuture() -> CoFuture<Element> {
        _innerChannel.receiveFuture()
    }
    
    /// Retrieves and removes an element from this channel.
    /// - Returns: Element from this channel if its not empty, or returns nill if the channel is empty or is closed or canceled.
    @inlinable public func poll() -> Element? {
        _innerChannel.poll()
    }
    
    /// Adds an observer callback to receive an element from this channel.
    /// - Parameter callback: The callback that is called when a value is received.
    @inlinable public func whenReceive(_ callback: @escaping (Result<Element, CoChannelError>) -> Void) {
        _innerChannel.whenReceive(callback)
    }
    
    /// Returns a number of elements in this channel.
    @inlinable public var count: Int {
        _innerChannel.count
    }
    
    /// Returns `true` if the channel is empty (contains no elements), which means no elements to receive.
    @inlinable public var isEmpty: Bool {
        _innerChannel.isEmpty
    }
    
    // MARK: - map
    
    /// Returns new `Receiver` that provides transformed values from this `CoChannel`.
    /// - Parameter transform: A mapping closure.
    /// - returns: A `Receiver` with transformed values.
    @inlinable public func map<T>(_ transform: @escaping (Element) -> T) -> CoChannel<T>.Receiver {
        _innerChannel.map(transform)
    }
    
    // MARK: - close
    
    /// Closes this channel. No more send should be performed on the channel.
    /// - Returns: `true` if closed successfully or `false` if channel is already closed or canceled.
    @discardableResult @inlinable public func close() -> Bool {
        _innerChannel.close()
    }
    
    /// Returns `true` if the channel is closed.
    @inlinable public var isClosed: Bool {
        _innerChannel.isClosed
    }
    
    // MARK: - cancel
    
    /// Closes the channel and removes all buffered sent elements from it.
    @inlinable public func cancel() {
        _innerChannel.cancel()
    }
    
    /// Returns `true` if the channel is canceled.
    @inlinable public var isCanceled: Bool {
        _innerChannel.isCanceled
    }
    
    /// Adds an observer callback that is called when the `CoChannel` is canceled.
    /// - Parameter callback: The callback that is called when the `CoChannel` is canceled.
    @inlinable public func whenCanceled(_ callback: @escaping () -> Void) {
        _innerChannel.whenCanceled(callback)
    }
    
    // MARK: - complete
    
    /// Adds an observer callback that is called when the `CoChannel` is completed (closed, canceled or deinited).
    /// - Parameter callback: The callback that is called when the `CoChannel` is completed.
    @inlinable public func whenComplete(_ callback: @escaping () -> Void) {
        _innerChannel.whenComplete(callback)
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
        _innerChannel.makeIterator()
    }
    
}
