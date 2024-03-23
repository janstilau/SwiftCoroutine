
extension CoChannel {
    
    /// A `CoChannel` wrapper that provides receive-only functionality.
    public class Receiver {
        
        /// The type of channel buffer.
        public var bufferType: BufferType { .none }
        
        // MARK: - receive
        
        /// Retrieves and removes an element from this channel if it’s not empty,
        /// or suspends a coroutine while the channel is empty.
        /// - Throws: CoChannelError when canceled or closed.
        /// - Returns: Removed value from the channel.
        public func awaitReceive() throws -> Element {
            throw CoChannelError.canceled
        }
        
        /// Creates `CoFuture` with retrieved value from this channel.
        /// - Returns: `CoFuture` with a future value from the channel.
        @inlinable public final func receiveFuture() -> CoFuture<Element> {
            let promise = CoPromise<Element>()
            // 当, 当前的 Channel 收到值之后, 触发 Future 的 promise.
            whenReceive(promise.complete)
            return promise
        }
        
        /// Retrieves and removes an element from this channel.
        /// - Returns: Element from this channel if its not empty, or returns nill if the channel is empty or is closed or canceled.
        public func poll() -> Element? { nil }
        
        /// Adds an observer callback to receive an element from this channel.
        /// - Parameter callback: The callback that is called when a value is received.
        public func whenReceive(_ callback: @escaping (Result<Element, CoChannelError>) -> Void) {}
        
        /// Returns a number of elements in this channel.
        public var count: Int { 0 }
        
        /// Returns `true` if the channel is empty (contains no elements), which means no elements to receive.
        public var isEmpty: Bool { true }
        
        // MARK: - map
        
        /// Returns new `Receiver` that provides transformed values from this `CoChannel`.
        /// - Parameter transform: A mapping closure.
        /// - returns: A `Receiver` with transformed values.
        // 一个 Opertor.
        public final func map<T>(_ transform: @escaping (Element) -> T) -> CoChannel<T>.Receiver {
            _CoChannelMap(receiver: self, transform: transform)
        }
        
        // MARK: - close
        
        /// Returns `true` if the channel is closed.
        public var isClosed: Bool { true }
        
        // MARK: - cancel
        
        /// Closes the channel and removes all buffered sent elements from it.
        public func cancel() {}
        
        /// Returns `true` if the channel is canceled.
        public var isCanceled: Bool { true }
        
        /// Adds an observer callback that is called when the `CoChannel` is canceled.
        /// - Parameter callback: The callback that is called when the `CoChannel` is canceled.
        public final func whenCanceled(_ callback: @escaping () -> Void) {
            whenFinished { if $0 == .canceled { callback() } }
        }
        
        // MARK: - complete
        
        /// Adds an observer callback that is called when the `CoChannel` is completed (closed, canceled or deinited).
        /// - Parameter callback: The callback that is called when the `CoChannel` is completed.
        public final func whenComplete(_ callback: @escaping () -> Void) {
            whenFinished { _ in callback() }
        }
        
        internal func whenFinished(_ callback: @escaping (CoChannelError?) -> Void) {}
        
    }
    
}

extension CoChannel.Receiver {
    
    // MARK: - sequence
    
    /// Make an iterator which successively retrieves and removes values from the channel.
    ///
    /// If `next()` was called inside a coroutine and there are no more elements in the channel,
    /// then the coroutine will be suspended until a new element will be added to the channel or it will be closed or canceled.
    /// - Returns: Iterator for the channel elements.
    /// 创建一个迭代器，用于逐个检索并移除通道中的值。
    ///
    /// 如果在协程内部调用了 `next()`，并且通道中没有更多的元素，
    /// 那么协程将被挂起，直到一个新元素被添加到通道中，或者通道被关闭或取消。
    /// - Returns: 通道元素的迭代器。

    @inlinable public func makeIterator() -> AnyIterator<Element> {
        AnyIterator { 
            CoroutineSpace.isInsideCoroutine ? try? self.awaitReceive() : self.poll() }
    }
    
}
